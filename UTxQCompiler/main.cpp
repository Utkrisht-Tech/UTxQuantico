#include "xQGrammer/xQGrammer.cpp"
int main(){
    //init();
    //for(auto x:keywords){
    //    cout<<x.first<<" "<<x.second<<"\n";
    //}
    Position pos;
    pos.fileName = "UTXQ";
    pos.line = 10;
    pos.column = 5;
    cout<<pos.posToString();
    return 0;
}