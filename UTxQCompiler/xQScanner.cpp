#include <bits/stdc++.h>
#include "Grammer/tokens.cpp"

using namespace std;

struct xQScanner {
    string curtext;
    int curpos;
    int curline;
};
struct Tk {
    Token kind;
    int pos_a;
    int pos_b;
    string text;
};
int isDigit(char ch){
    if(ch>='0' && ch<='9'){
        return 1;
    }
    return 0;
}

Tk NextTk(string inp,int len, int pos){
    int start=pos; Tk tk;
    tk.text="";
    tk.pos_a=start;
    int numLen=0;
    while(pos<=len){
        if(isDigit(inp[pos])){
            if(pos-start == numLen){
                tk.text += inp[pos];
                numLen++;
            }
            else{ cout<<"Error"; return tk; }
        }
        pos++;
    }
    tk.pos_b=pos;
    tk.kind = Token.NUM;
    return tk;
}

auto xQLexer(string inp){
    xQScanner sc; int _start=sc.curpos=0;Tk Tok;
    int len=inp.size();
    while(sc.curpos<=len && _start<=sc.curpos){
        Tok = NextTk(inp,len,_start);
        cout<<"Found:"<<Tok.text<<" as "<<Tok.kind<<"\n";
        sc.curpos=Tok.pos_b; _start=sc.curpos;
    }
    return;
}