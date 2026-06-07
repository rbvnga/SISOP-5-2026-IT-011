void putInMemory(int segment, int address, char character);
int getChar();
int getFromMemory(int segment, int address);

void main() {
    int cursor;
    int pos;
    char c;
    int cmdstart;
    int cmdlen;
    int i;
    char color;
    int row;
    int match;
    int a;
    int b;
    int n;
    int temp;
    int j;
    char rev[10];
    char buf[10];

    cursor = 0;
    color = 0x07;
    row = 0;

    /* clear screen */
    i = 0;
    while (i < 2000) {
        pos = i * 2;
        putInMemory(0xB800, pos, ' ');
        pos = pos + 1;
        putInMemory(0xB800, pos, 0x07);
        i = i + 1;
    }

    /* welcome line 0 */
    cursor = 0;
    i = 0;
    c = "Welcome to Assistant's Last Gift"[i];
    while (c != '\0') {
        pos = cursor * 2;
        putInMemory(0xB800, pos, c);
        pos = pos + 1;
        putInMemory(0xB800, pos, color);
        cursor = cursor + 1;
        i = i + 1;
        c = "Welcome to Assistant's Last Gift"[i];
    }

    /* type help line 1 */
    cursor = 80;
    i = 0;
    c = "type 'help'"[i];
    while (c != '\0') {
        pos = cursor * 2;
        putInMemory(0xB800, pos, c);
        pos = pos + 1;
        putInMemory(0xB800, pos, color);
        cursor = cursor + 1;
        i = i + 1;
        c = "type 'help'"[i];
    }

    row = 2;
    cursor = row * 80;

    while (1) {

        /* print "> " */
        pos = cursor * 2;
        putInMemory(0xB800, pos, '>');
        pos = pos + 1;
        putInMemory(0xB800, pos, color);
        cursor = cursor + 1;
        pos = cursor * 2;
        putInMemory(0xB800, pos, ' ');
        pos = pos + 1;
        putInMemory(0xB800, pos, color);
        cursor = cursor + 1;

        cmdstart = cursor;
        cmdlen = 0;

        while (1) {
            c = getChar();
            if (c == '\r') break;
            if (c == '\b') {
                if (cmdlen > 0) {
                    cmdlen = cmdlen - 1;
                    cursor = cursor - 1;
                    pos = cursor * 2;
                    putInMemory(0xB800, pos, ' ');
                    pos = pos + 1;
                    putInMemory(0xB800, pos, color);
                }
            } else if (c >= 32) {
                pos = cursor * 2;
                putInMemory(0xB800, pos, c);
                pos = pos + 1;
                putInMemory(0xB800, pos, color);
                cursor = cursor + 1;
                cmdlen = cmdlen + 1;
            }
        }

        row = row + 1;
        cursor = row * 80;
        match = 0;

        /* === check === */
        if (match == 0 && cmdlen == 5) {
            if (getFromMemory(0xB800, cmdstart*2+0) == 'c' &&
                getFromMemory(0xB800, cmdstart*2+2) == 'h' &&
                getFromMemory(0xB800, cmdstart*2+4) == 'e' &&
                getFromMemory(0xB800, cmdstart*2+6) == 'c' &&
                getFromMemory(0xB800, cmdstart*2+8) == 'k') {
                match = 1;
                i = 0;
                c = "ok"[i];
                while (c != '\0') {
                    pos = cursor * 2;
                    putInMemory(0xB800, pos, c);
                    pos = pos + 1;
                    putInMemory(0xB800, pos, color);
                    cursor = cursor + 1;
                    i = i + 1;
                    c = "ok"[i];
                }
                row = row + 1;
                cursor = row * 80;
            }
        }

        /* === help === */
        if (match == 0 && cmdlen == 4) {
            if (getFromMemory(0xB800, cmdstart*2+0) == 'h' &&
                getFromMemory(0xB800, cmdstart*2+2) == 'e' &&
                getFromMemory(0xB800, cmdstart*2+4) == 'l' &&
                getFromMemory(0xB800, cmdstart*2+6) == 'p') {
                match = 1;
                i = 0;
                c = "check add sub fac season triangle clear about"[i];
                while (c != '\0') {
                    pos = cursor * 2;
                    putInMemory(0xB800, pos, c);
                    pos = pos + 1;
                    putInMemory(0xB800, pos, color);
                    cursor = cursor + 1;
                    i = i + 1;
                    c = "check add sub fac season triangle clear about"[i];
                }
                row = row + 1;
                cursor = row * 80;
            }
        }

        /* === clear === */
        if (match == 0 && cmdlen == 5) {
            if (getFromMemory(0xB800, cmdstart*2+0) == 'c' &&
                getFromMemory(0xB800, cmdstart*2+2) == 'l' &&
                getFromMemory(0xB800, cmdstart*2+4) == 'e' &&
                getFromMemory(0xB800, cmdstart*2+6) == 'a' &&
                getFromMemory(0xB800, cmdstart*2+8) == 'r') {
                match = 1;
                i = 0;
                while (i < 2000) {
                    pos = i * 2;
                    putInMemory(0xB800, pos, ' ');
                    pos = pos + 1;
                    putInMemory(0xB800, pos, 0x07);
                    i = i + 1;
                }
                color = 0x07;
                row = 0;
                cursor = 0;
            }
        }

        /* === add === */
        if (match == 0 && cmdlen >= 5) {
            if (getFromMemory(0xB800, cmdstart*2+0) == 'a' &&
                getFromMemory(0xB800, cmdstart*2+2) == 'd' &&
                getFromMemory(0xB800, cmdstart*2+4) == 'd' &&
                getFromMemory(0xB800, cmdstart*2+6) == ' ') {
                match = 1;
                i = 4;
                a = 0;
                while (getFromMemory(0xB800, (cmdstart+i)*2) >= '0' &&
                       getFromMemory(0xB800, (cmdstart+i)*2) <= '9') {
                    a = a * 10 + (getFromMemory(0xB800, (cmdstart+i)*2) - '0');
                    i = i + 1;
                }
                i = i + 1;
                b = 0;
                while (getFromMemory(0xB800, (cmdstart+i)*2) >= '0' &&
                       getFromMemory(0xB800, (cmdstart+i)*2) <= '9') {
                    b = b * 10 + (getFromMemory(0xB800, (cmdstart+i)*2) - '0');
                    i = i + 1;
                }
                n = a + b;
                j = 0;
                if (n == 0) {
                    rev[0] = '0';
                    j = 1;
                } else {
                    temp = n;
                    while (temp > 0) {
                        rev[j] = '0' + (temp - (temp/10)*10);
                        temp = temp / 10;
                        j = j + 1;
                    }
                }
                i = 0;
                while (i < j) {
                    pos = cursor * 2;
                    putInMemory(0xB800, pos, rev[j-i-1]);
                    pos = pos + 1;
                    putInMemory(0xB800, pos, color);
                    cursor = cursor + 1;
                    i = i + 1;
                }
                row = row + 1;
                cursor = row * 80;
            }
        }

        /* === sub === */
        if (match == 0 && cmdlen >= 5) {
            if (getFromMemory(0xB800, cmdstart*2+0) == 's' &&
                getFromMemory(0xB800, cmdstart*2+2) == 'u' &&
                getFromMemory(0xB800, cmdstart*2+4) == 'b' &&
                getFromMemory(0xB800, cmdstart*2+6) == ' ') {
                match = 1;
                i = 4;
                a = 0;
                while (getFromMemory(0xB800, (cmdstart+i)*2) >= '0' &&
                       getFromMemory(0xB800, (cmdstart+i)*2) <= '9') {
                    a = a * 10 + (getFromMemory(0xB800, (cmdstart+i)*2) - '0');
                    i = i + 1;
                }
                i = i + 1;
                b = 0;
                while (getFromMemory(0xB800, (cmdstart+i)*2) >= '0' &&
                       getFromMemory(0xB800, (cmdstart+i)*2) <= '9') {
                    b = b * 10 + (getFromMemory(0xB800, (cmdstart+i)*2) - '0');
                    i = i + 1;
                }
                n = a - b;
                j = 0;
                if (n == 0) {
                    rev[0] = '0';
                    j = 1;
                } else {
                    temp = n;
                    while (temp > 0) {
                        rev[j] = '0' + (temp - (temp/10)*10);
                        temp = temp / 10;
                        j = j + 1;
                    }
                }
                i = 0;
                while (i < j) {
                    pos = cursor * 2;
                    putInMemory(0xB800, pos, rev[j-i-1]);
                    pos = pos + 1;
                    putInMemory(0xB800, pos, color);
                    cursor = cursor + 1;
                    i = i + 1;
                }
                row = row + 1;
                cursor = row * 80;
            }
        }

        /* === fac === */
        if (match == 0 && cmdlen >= 5) {
            if (getFromMemory(0xB800, cmdstart*2+0) == 'f' &&
                getFromMemory(0xB800, cmdstart*2+2) == 'a' &&
                getFromMemory(0xB800, cmdstart*2+4) == 'c' &&
                getFromMemory(0xB800, cmdstart*2+6) == ' ') {
                match = 1;
                i = 4;
                n = 0;
                while (getFromMemory(0xB800, (cmdstart+i)*2) >= '0' &&
                       getFromMemory(0xB800, (cmdstart+i)*2) <= '9') {
                    n = n * 10 + (getFromMemory(0xB800, (cmdstart+i)*2) - '0');
                    i = i + 1;
                }
                if (n > 8) {
                    i = 0;
                    c = "know your limit little bro."[i];
                    while (c != '\0') {
                        pos = cursor * 2;
                        putInMemory(0xB800, pos, c);
                        pos = pos + 1;
                        putInMemory(0xB800, pos, color);
                        cursor = cursor + 1;
                        i = i + 1;
                        c = "know your limit little bro."[i];
                    }
                } else {
                    a = 1;
                    i = 2;
                    while (i <= n) {
                        a = a * i;
                        i = i + 1;
                    }
                    j = 0;
                    if (a == 0) {
                        rev[0] = '0';
                        j = 1;
                    } else {
                        temp = a;
                        while (temp > 0) {
                            rev[j] = '0' + (temp - (temp/10)*10);
                            temp = temp / 10;
                            j = j + 1;
                        }
                    }
                    i = 0;
                    while (i < j) {
                        pos = cursor * 2;
                        putInMemory(0xB800, pos, rev[j-i-1]);
                        pos = pos + 1;
                        putInMemory(0xB800, pos, color);
                        cursor = cursor + 1;
                        i = i + 1;
                    }
                }
                row = row + 1;
                cursor = row * 80;
            }
        }

        /* === season === */
        if (match == 0 && cmdlen >= 8) {
            if (getFromMemory(0xB800, cmdstart*2+0) == 's' &&
                getFromMemory(0xB800, cmdstart*2+2) == 'e' &&
                getFromMemory(0xB800, cmdstart*2+4) == 'a' &&
                getFromMemory(0xB800, cmdstart*2+6) == 's' &&
                getFromMemory(0xB800, cmdstart*2+8) == 'o' &&
                getFromMemory(0xB800, cmdstart*2+10) == 'n' &&
                getFromMemory(0xB800, cmdstart*2+12) == ' ') {
                match = 1;
                /* winter */
                if (getFromMemory(0xB800, cmdstart*2+14) == 'w') {
                    color = 0x09;
                    i = 0;
                    c = "winter mode"[i];
                    while (c != '\0') {
                        pos = cursor * 2;
                        putInMemory(0xB800, pos, c);
                        pos = pos + 1;
                        putInMemory(0xB800, pos, color);
                        cursor = cursor + 1;
                        i = i + 1;
                        c = "winter mode"[i];
                    }
                /* spring */
                } else if (getFromMemory(0xB800, cmdstart*2+14) == 's' &&
                           getFromMemory(0xB800, cmdstart*2+16) == 'p') {
                    color = 0x0A;
                    i = 0;
                    c = "spring mode"[i];
                    while (c != '\0') {
                        pos = cursor * 2;
                        putInMemory(0xB800, pos, c);
                        pos = pos + 1;
                        putInMemory(0xB800, pos, color);
                        cursor = cursor + 1;
                        i = i + 1;
                        c = "spring mode"[i];
                    }
                /* summer */
                } else if (getFromMemory(0xB800, cmdstart*2+14) == 's' &&
                           getFromMemory(0xB800, cmdstart*2+16) == 'u') {
                    color = 0x0E;
                    i = 0;
                    c = "summer mode"[i];
                    while (c != '\0') {
                        pos = cursor * 2;
                        putInMemory(0xB800, pos, c);
                        pos = pos + 1;
                        putInMemory(0xB800, pos, color);
                        cursor = cursor + 1;
                        i = i + 1;
                        c = "summer mode"[i];
                    }
                /* fall */
                } else if (getFromMemory(0xB800, cmdstart*2+14) == 'f') {
                    color = 0x0C;
                    i = 0;
                    c = "fall mode"[i];
                    while (c != '\0') {
                        pos = cursor * 2;
                        putInMemory(0xB800, pos, c);
                        pos = pos + 1;
                        putInMemory(0xB800, pos, color);
                        cursor = cursor + 1;
                        i = i + 1;
                        c = "fall mode"[i];
                    }
                /* radiant */
                } else if (getFromMemory(0xB800, cmdstart*2+14) == 'r') {
                    color = 0x0D;
                    i = 0;
                    c = "radiant mode"[i];
                    while (c != '\0') {
                        pos = cursor * 2;
                        putInMemory(0xB800, pos, c);
                        pos = pos + 1;
                        putInMemory(0xB800, pos, color);
                        cursor = cursor + 1;
                        i = i + 1;
                        c = "radiant mode"[i];
                    }
                }
                row = row + 1;
                cursor = row * 80;
            }
        }

        /* === triangle === */
        if (match == 0 && cmdlen >= 10) {
            if (getFromMemory(0xB800, cmdstart*2+0) == 't' &&
                getFromMemory(0xB800, cmdstart*2+2) == 'r' &&
                getFromMemory(0xB800, cmdstart*2+4) == 'i' &&
                getFromMemory(0xB800, cmdstart*2+6) == 'a' &&
                getFromMemory(0xB800, cmdstart*2+8) == 'n' &&
                getFromMemory(0xB800, cmdstart*2+10) == 'g' &&
                getFromMemory(0xB800, cmdstart*2+12) == 'l' &&
                getFromMemory(0xB800, cmdstart*2+14) == 'e' &&
                getFromMemory(0xB800, cmdstart*2+16) == ' ') {
                match = 1;
                i = 9;
                n = 0;
                while (getFromMemory(0xB800, (cmdstart+i)*2) >= '0' &&
                       getFromMemory(0xB800, (cmdstart+i)*2) <= '9') {
                    n = n * 10 + (getFromMemory(0xB800, (cmdstart+i)*2) - '0');
                    i = i + 1;
                }
                i = 1;
                while (i <= n) {
                    j = 0;
                    while (j < i) {
                        pos = cursor * 2;
                        putInMemory(0xB800, pos, 'x');
                        pos = pos + 1;
                        putInMemory(0xB800, pos, color);
                        cursor = cursor + 1;
                        j = j + 1;
                    }
                    row = row + 1;
                    cursor = row * 80;
                    i = i + 1;
                }
            }
        }

        /* reset jika layar penuh */
        if (row >= 23) {
            i = 0;
            while (i < 2000) {
                pos = i * 2;
                putInMemory(0xB800, pos, ' ');
                pos = pos + 1;
                putInMemory(0xB800, pos, 0x07);
                i = i + 1;
            }
            row = 0;
            cursor = 0;
        }
    }
}
