#include <sys/wait.h>
#include <unistd.h>

int getWuntraced() {
    return WUNTRACED;
}

_Bool wifexited(int status) {
    if (WIFEXITED(status)) return 1;
    return 0;
}


_Bool wifsignaled(int status) {
    if (WIFSIGNALED(status)) return 1;
    return 0;
}


