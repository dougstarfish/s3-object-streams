#define _GNU_SOURCE
#include <dirent.h>     /* Defines DT_* constants */
#include <errno.h>
//#include <atomic.h>
#include <fcntl.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/time.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <signal.h>
#include <pthread.h>

/*
 * This is a fast way to walk all of the directories in parallel without 
 * executing a stat call. It works with NFS, but not many local file systems
 * where 'type' is undefined.
 * BUGS:
 * * It has a latent bug in the calculation of the number of active threads.
 *   (race condition)
 * * the tally on the total isn't 100% accurate. Mostly because enough time
 * hasn't been spent on figuring out how to end cleanly (again, active
 * thread counting would help)
 * * it really should take debug level as an argument
 */

static int debug=1;
static int objs;
static int thractive;
static struct timeval startsec;
static pthread_mutex_t MP_mutex;
static pthread_mutex_t CP_mutex;

typedef struct {
	long tid;			// thread_id (given id)
    long wfd;			// write file descriptor
	long local_count;	// count
	DIR *dh;			// opendir handle
	struct dirent *dp;  // readdir pointer
    char dirname[MAXPATHLEN];
} targ_t;

#ifdef NTHREADS
static nthreads = NTHREADS;
#else
static nthreads = 1;
#endif

static targ_t allthrd[NTHREADS];

// 
// Show all worker status
// 
void dump_workers (void) {
	int i;

    fprintf(stderr, "dumping workers\n");
	for (i = 0; i < nthreads; i++) {
		printf("%d %d %s\n", allthrd[i].tid, allthrd[i].wfd, allthrd[i].dirname);
	}
	return;
}

//
// show stats and exit program
//
void stats_and_exit (const int signum) {
    struct timeval now;
    double timedif;

    gettimeofday(&now, NULL);
    timedif = (now.tv_sec - startsec.tv_sec) + (now.tv_usec - startsec.tv_usec) / 1000000;
    printf("handled %d objs in %1.3f seconds: %2.1f objs/sec\n",
        objs, timedif, objs/timedif);
	dump_workers();
	sleep(10);
    exit(signum);
}
        
//
// cleanup after exiting a thread. adjust number of active threads
// 
int exit_thread(targ_t *tp) {
	if (pthread_mutex_lock(&MP_mutex)) {
		perror("couldn't lock mutex");
		exit(-1);
	}
    __sync_fetch_and_add(&thractive, -1);		// active threads available
    printf("%lu closing active thread %d, %s\n", pthread_self(), thractive, tp->dirname);
	tp->tid = -1;								// reset this struct for use
	pthread_mutex_unlock(&MP_mutex);
    pthread_exit(NULL);
    return;
}

//
// find an unused thread in the pool of workers
//
targ_t *find_unused_worker (void) {
	int i;
	targ_t *tp;

	tp = (targ_t *) NULL;
	// allow slop in changing thread count
	for (i = 0; i < nthreads; i++) {
		if (allthrd[i].tid == -1) {
			allthrd[i].tid = i;
			tp = &(allthrd[i]);
			return (tp);
		}
	}
	return (tp);
}

// forward declaration
static void *do_thrd(void *targ);

//
// walk the dir and count the objects
// 
void do_dir(char *dirname, int wfd) {
	DIR *dh;
	struct dirent *dp;
	targ_t *tp;			// threadpointer
	targ_t tlocal;
    pthread_t newthread;
	char newdir[MAXPATHLEN];
	int local_count;

	local_count = 0;
	if (debug > 1) 
		printf("%lu processing dir: %s\n", pthread_self(), dirname);
    if ((dh = opendir(dirname)) == (DIR *) NULL) {
        fprintf(stderr, "%lu failed opening dir: %s, %s\n", pthread_self(), dirname, strerror(errno));
        return;
    }
	if (debug > 2)
		printf("%lu after diropen: %s\n", pthread_self(), dirname);
    while ((dp = readdir(dh)) != (struct dirent *) NULL) {
        if ( !strcmp(dp->d_name, ".") || !strcmp(dp->d_name, "..") )
             continue;
        
        //__sync_fetch_and_add(&objs, 1);
		if (debug > 2)
			printf("%lu obj %s/%s %d\n", pthread_self(), dirname, dp->d_name, dp->d_type);
        // need a mutex aronud the sprintf until the new thread is started
        local_count++;
        if (dp->d_type == DT_DIR) {
            if (sprintf(newdir, "%s/%s", dirname, dp->d_name) < 0 ) {
                perror("couldn't append dirname");
                stats_and_exit(-1);
            }
            // descend
            // both of these are global
			// if there are no unused threads, just recurse ourselves
            if (thractive >= nthreads) {
                // do it in this thread to avoid deadlock; recurse
				if (debug > 0) 
					printf("%lu active threads %d >= nthreads %d\n", pthread_self(), thractive, nthreads);
                do_dir(newdir, wfd);
                continue;
            }
			// we have free worker threads, so start a new one after getting a mutex
            if (pthread_mutex_lock(&MP_mutex)) {
                perror("couldn't lock mutex");
                stats_and_exit(-1);
            }
			if ((tp = find_unused_worker()) == NULL) {
				//fprintf(stderr, "%lu %d active threads of %d\n", pthread_self(), thractive, nthreads);
				fprintf(stderr, "%lu big error; should be workers but aren't. proceeding. %d of %d \n", pthread_self(), thractive, nthreads);
				dump_workers();
                do_dir(newdir, wfd);
				continue;
			}
            __sync_fetch_and_add(&thractive, 1);
			strcpy(tp->dirname, newdir);
			tp->wfd = wfd;
			tp->tid = thractive;
			if (debug > 1) 
				printf("%lu calling new active thread. oldcnt %d for %s\n", pthread_self(), thractive, newdir );
            pthread_create(&newthread, NULL, do_thrd, tp);
			if (debug > 0)
				printf("%lu created thread %lu for %s\n", pthread_self(), newthread, newdir);
            pthread_detach(newthread);
            pthread_mutex_unlock(&MP_mutex);
        }
    }
    closedir(dh);
	if (write(wfd, (char *) &local_count, 4) < 0) {
		fprintf(stderr, "%d failed writing count to parent\n", pthread_self());
	} else if (debug > 1) {
		printf("%lu processed %d objs\n", pthread_self(), local_count);
	}
    return;
}

// master thread processor
// establishes current thread context and issues call to process directory in thread-
// specific function
void *do_thrd(void *targ) {
    targ_t *curthrd = (targ_t *) targ;

	if (pthread_mutex_lock(&MP_mutex)) {
		perror("couldn't lock mutex");
		stats_and_exit(-1);
	}
	//__sync_fetch_and_add(&thractive, 1);		// increment number of active threads
	if (debug > 0)
		printf("%lu new thread %d with dir %s\n", pthread_self(), thractive, curthrd->dirname);
	pthread_mutex_unlock(&MP_mutex);
    
	do_dir(curthrd->dirname, curthrd->wfd);		// process directory
    exit_thread(curthrd);
    return;
}

int main(int argc, char *argv[]) {
    pthread_t newthread;
    int pipefd[2];
	int i;
    int ret;
	int ecount=0;				// error count on read
    struct sigaction sa;
    long readobjs;              // from worker threads

    sa.sa_handler = &stats_and_exit;

    thractive = 0;      // set initial thread count
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGHUP, &sa, NULL);
    sigaction(SIGTSTP, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);

    objs = 1;           // for the starting point
    gettimeofday(&startsec, NULL);

	// initialize all thread ids to -1
	for (i = 1; i < nthreads; i++) {
	    allthrd[i].tid = -1;
	}
    thractive = 1;	 		// always start with one dir processor
    if (pipe2(pipefd, O_NONBLOCK) < 0) {
        perror("pipe failed. aborting");
        exit(-1);
    }
	strcpy(allthrd[0].dirname, (argc > 1 ? argv[1] : "."));
	allthrd[0].wfd = pipefd[1];
	allthrd[0].tid = 0;
	printf("starting with %s, %d\n", allthrd[0].dirname, allthrd[0].wfd);
    
    if (pthread_create(&newthread, NULL, do_thrd, &allthrd[0])) {
		perror("couldn't create initial thread");
		exit(-1);
	}
	puts ("past thread in main");
    pthread_detach(newthread);
    // do_dir(argc > 1 ? argv[1] : ".");
    
	//sleep(1);
	//close(pipefd[1]);	// close our local side
    // wait for all threads to end
    while(thractive > 0) {
        while ((ret = read(pipefd[0], (char *) &readobjs, 4)) != EOF) {
			objs += readobjs;
			if (debug > 1)
				printf("read %d %d\n", objs, readobjs);
			ecount = 0;		// reset counter
        }
        if (ret < 0 && errno == EOF) {               // no more worker writers
			if (debug > 0)
				puts("EOF all threads done");
            stats_and_exit(0);
        }
		if (debug > 2)
			fprintf(stderr, "waiting on active threads %d\n", thractive);
		usleep(50000);	// busy wait 50 msec
		ecount++;
		if (debug > 2) 
			puts("sleep...");
		if (ecount > 50)  {
			fprintf(stderr, "read error count triggered. exiting\n");
			stats_and_exit(-1);
		}
    }
    
	if (debug > 0)
		puts("all threads done");
    
    stats_and_exit(0);
}
