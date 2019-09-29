#include "Grammer/tokens.cpp"
#include <iostream>
#include <bits/stdc++.h>


using namespace std;

int main(){
    char tk;
    cin>>tk;
    string ans = (tk==Grammer::COLON) ? "COLON":"UNKNOWN";
    cout<<ans<<"\n";
    return 0;
}