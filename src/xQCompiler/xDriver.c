#include "../xQLib/x.h"

int main(int argc, char **argv) {
    if(argc!=2){
        fprintf(stderr, "Number of Arguments incorrect\n");
        return 1;
    }
    printf(".intel_syntax noprefix\n");
    printf(".global main\n");
    printf("main:\n");
    printf("    mov rax, %d\n", atoi(argv[1]));
    printf("    ret\n");
    return 0;
}
