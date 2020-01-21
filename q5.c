#define Buffer ((char *)*(int far *)0x200)

void my_printf(char * s, ...) {
    int stack = 0;
    int sceen = 0;
    int push_num = 0;
    int q = 0;
    while(*s) {
        if(*s == '%') {
            s++;
            switch(*s) {
                case 'c':
                    *(char far *)(0xb80007d0 + sceen++) = *(int *)(_BP + 6 + (stack++)*2);
                    *(char far *)(0xb80007d0 + sceen++) = 2;
                    break;
                case 'd':
                    push_num = 0;
                    q = *(int *)(_BP + 6 + (stack++)*2);
                    if(!q) {
                        *(char far *)(0xb80007d0 + sceen++) = '0';
                        *(char far *)(0xb80007d0 + sceen++) = 2;
                    }
                    while(q) {
                        _SP -= 2;
                        *(int *)_SP = (q%10) + 0x30;
                        push_num++;
                        q /= 10;
                    }
                    while(push_num) {
                        *(char far *)(0xb80007d0 + sceen++) = *(int *)_SP;
                        *(char far *)(0xb80007d0 + sceen++) = 2;
                        _SP += 2;
                        push_num--;
                    }
                    break;
            }
        } else {
            *(char far *)(0xb80007d0 + sceen++) = *s;
            *(char far *)(0xb80007d0 + sceen++) = 2;
        }
        s++;
    }
}

void main() {
    my_printf("%c = %d = %c = %d",'a',512,'b',120);
    printf("%c - %d - %c - %d",'a','d','c','d');
}
