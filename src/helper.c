#include <sys/wait.h>
#include <stdbool.h>
#include <unistd.h>

int getWuntraced() {
    return WUNTRACED;
}

bool wifexited(int status) {
    if (WIFEXITED(status)) return true;
    return false;
}


bool wifsignaled(int status) {
    if (WIFSIGNALED(status)) return true;
    return false;
}


