#define NoOfTk 105 // Total no. of tokens in UTxQ
// Constants for precedence-based expression parsing
#define LowPrec 0 // non-operators
#define UnaryPrec 6
#define HighPrec 7

using namespace std;
//
// Token is a set of lexical tokens of UTxQuantico programming language.
typedef int Token;
//
// List of Basic Tokens used in UTxQuantico
//
enum ToKeN {
    xQUNKNOWN=0,
    xQEOF,			// EndMarker
    xQNEWLINE,
    xQCOMMENT,
    //General Tokens
    literals_start=4,
    NAME,           // fn name or var name
    NUM,            // Different Types of Supported Numbers
    STR,            // String
    CHAR,           // `A`
    literals_end=9,
    operators_start=10,
    //Structural Operators
    SQUOTE,         // '
    DQUOTE,         // "
    DOT,            // .
    COMMA,          // ,
	SEMICOLON,      // ;
	COLON,          // :
    LCBR,           // {
	RCBR,           // }
	LPAR,           // (
	RPAR,           // )
	LSBR,           // [
	RSBR,           // ]
    //Mathematical Operators
    PLUS,           // +
	MINUS,          // -
	STAR,           // *
	SLASH,          // /
	MODULO,         // %
	STSTAR,		    // **
    // Logical Operators
	XOR,            // ^
	PIPE,           // |
	INC,            // ++
	DEC,            // --
	AND,            // &&
    AND_NOT,        // &^
	L_OR,           // ||
	NOT,            // !
	BIT_NOT,        // ~
    LSHIFT,         // <<
    RSHIFT,         // >>
    // Comparison Operators
	EQEQUAL,        // ==
	NOTEQUAL,       // !=
    LESSER,         // <
	LESSEREQUAL,    // <=
    GREATER,        // >
	GREATEREQUAL,   // >=
    // Symbols
    QUESTION,       // ?
    AMPER,          // &
	HASH,           // #
	DOLLAR,         // $
    AT,             // @
	ARROW,          // =>
    BSLASH,         // BackSlash
    DOTDOT,         // ..
	// Assignment Operators
	ASSIGN,         // =
	DECL_ASSIGN,    // :=
	PLUS_ASSIGN,    // +=
	MINUS_ASSIGN,   // -=
	SLASH_ASSIGN,   // /=
	STAR_ASSIGN,    // *=
	XOR_ASSIGN,     // ^=
	MOD_ASSIGN,     // %=
	OR_ASSIGN,      // |=
	AND_ASSIGN,     // &=
    AND_NOT_ASSIGN, // &^=
    AT_ASSIGN,      // @=
	RSHIFT_ASSIGN,  // >>=
	LSHIFT_ASSIGN,  // <<=
    operators_end=68,
	// keywords
    keywords_start=69,
	key_as,
	key_assert,
	key_atomic,
	key_break,
	key_case,
	key_const,
	key_continue,
	key_default,
	key_defer,
	key_else,
	key_or_else,
	key_embed,
	key_enum,
	key_false,
	key_for,
	key_function,
	key_global,
	key_goto,
	key_if,
	key_import,
	key_in,
	key_interface,
	key_match,
	key_module,
	key_mutable,
	key_none,
	key_public,
	key_private,
	key_return,
	key_static,
	key_struct,
	key_switch,
	key_true,
	key_type,
	keywords_end=104
};
//
// Assign Values to Tokens
//
map<int, string> tokens = {
    {xQUNKNOWN, "xQUNKNOWN"},
    {xQEOF, "xQEOF"},
    {xQNEWLINE, "xQNEWLINE"},
    {xQCOMMENT, "xQCOMMENT"},
    //General Tokens
    {NAME, "NAME"},
    {NUM, "NUM"},
    {STR, "STR"},
    {CHAR, "CHAR"},
    //Structural Operators
    {SQUOTE, "'"},
    {DQUOTE, "\""},
    {DOT, "."},
    {COMMA, ","},
	{SEMICOLON, ";"},
	{COLON, ":"},
    {LCBR, "{"},
    {RCBR, "}"},
    {LPAR, "("},
    {RPAR, ")"},
    {LSBR, "["},
    {RSBR, "]"},
    //Mathematical Operators
    {PLUS, "+"},
    {MINUS, "-"},
    {STAR, "*"},
    {SLASH, "/"},
    {MODULO, "%"},
	{STSTAR, "**"},
    // Logical Operators
	{XOR, "^"},
    {PIPE, "|"},
    {INC, "++"},
	{DEC, "--"},
	{AND, "&&"},
    {AND_NOT, "&^"},
	{L_OR, "||"},
	{NOT, "!"},
    {BIT_NOT, "~"},
    {LSHIFT, "<<"},
    {RSHIFT, ">>"},
    // Comparison Operators
	{EQEQUAL, "=="},
	{NOTEQUAL, "!="},
	{GREATEREQUAL, ">="},
	{LESSEREQUAL, "<="},
    {GREATER, ">"},
    {LESSER, "<"},
    // Symbols
    {QUESTION, "?"},
    {AMPER, "&"},
    {HASH, "#"},
    {DOLLAR, "$"},
    {AT, "@"},
    {ARROW, "->"},
    {BSLASH, "\\"},
    {DOTDOT, ".."},
	// Assignment Operators
	{ASSIGN, "="},
	{DECL_ASSIGN, ":="},
	{PLUS_ASSIGN, "+="},
	{MINUS_ASSIGN, "-="},
	{SLASH_ASSIGN, "/="},
	{STAR_ASSIGN, "*="},
	{XOR_ASSIGN, "^="},
	{MOD_ASSIGN, "%="},
	{OR_ASSIGN, "|="},
	{AND_ASSIGN, "&="},
    {AND_NOT_ASSIGN, "&^="},
    {AT_ASSIGN, "@="},
	{RSHIFT_ASSIGN, ">>="},
	{LSHIFT_ASSIGN, "<<="},
	// keywords
	{key_as, "as"},
	{key_assert, "assert"},
	{key_atomic, "atomic"},
	{key_break, "break"},
	{key_case, "case"},
	{key_const, "const"},
	{key_continue, "continue"},
	{key_default, "default"},
	{key_defer, "defer"},
	{key_else, "else"},
	{key_or_else, "or"},
	{key_embed, "embed"},
	{key_enum, "enum"},
	{key_false, "false"},
	{key_for, "for"},
	{key_function, "fn"},
	{key_global, "global"},
	{key_goto, "goto"},
	{key_if, "if"},
	{key_import, "import"},
	{key_in, "in"},
	{key_interface, "interface"},
	{key_match, "match"},
	{key_module, "module"},
	{key_mutable, "mut"},
	{key_none, "none"},
	{key_public, "pub"},
	{key_private, "priv"},
	{key_return, "return"},
	{key_static, "static"},
	{key_struct, "struct"},
	{key_switch, "switch"},
	{key_true, "true"},
	{key_type, "type"}
};
//
// TkToString: Returns string corresponding to the token tok.
//
string TkToString(Token tok) {
    string s = "";
    if(tok>=0 && tok<NoOfTk){
        s=tokens[tok];
    }
    if(s==""){
        s="Token("+to_string(int(tok))+")";
    }
    return s;
}
//
// TkPrecedence: Returns precedence of a binary operator OP.
// If not a binary operator, returns LowPrecedence.
//
int TkPrecedence(Token OP) {
    switch(OP) {
        case(L_OR):
		    return 1;
	    case AND:
		    return 2;
	    case(EQEQUAL, NOTEQUAL, LESSER, LESSEREQUAL, GREATER, GREATEREQUAL):
		    return 3;
	    case(PLUS, MINUS, PIPE, XOR):
		    return 4;
	    case(STAR, SLASH, MODULO, LSHIFT, RSHIFT, AMPER, AND_NOT):
		    return 5;
    } 
    return LowPrec;
}
//
// Create a map of just keywords. For further use.
//
map<string, Token> keywords;
void init(){
    keywords.clear();
    for(int i = keywords_start+1;i<keywords_end;i++){
        keywords[tokens[i]]=i;
    }
}
//
// TkMapper: Maps a name to its keyword (if not a keyword mapped to NAME).
//
Token TkMapper(string name){
    Token tok = keywords[name];
    if(tok) {
        return tok;
    }
    return NAME;
}
//
// Predicates :-
// isLiteral: Returns true for tokens that are identifiers and basic
// type literals; Returns false otherwise.
//
bool isLiteral(Token tok){ return (literals_start<tok && literals_end>tok); }
//
// isOperator: Returns true for tokens that are operators and delimiters; 
// Returns false otherwise.
//
bool isOperator(Token tok){ return (operators_start<tok && operators_end>tok); }
//
// isKeyword: Returns true for tokens that are keywords;
// Returns false otherwise.
//
bool isKeyword(Token tok){ return (keywords_start<tok && keywords_end>tok); }
//
// isCapital: Returns true if name starts with an upper-case letter.
//
bool isCapital(string name){ return isupper(name[0]); }
//
// isKeyword: Returns true if name is a UTxQ keyword, such as "fn","return" or "pub".
//
bool isKeyword(string name){
    if(auto tok = keywords[name]){
        return true;
    }
    return false;
}
//
// isName: Returns true if name is a UTxQ name(A sequence of 
// letters, digits, and underscores of size atleast 1, where the
// first char is not a digit). Keywords are not identifiers.
//
bool isName(string name){
    if(name!=""){
        if(char(name[0])>='0' && char(name[0])<='9'){
            return false;
        }
        for(auto ch:name){
            if((ch<'a' && ch>'z')&&(ch!='_')&&(ch<'A' && ch>'Z')&&(ch<'0' && ch>'9')){
                return false;
            }
        }
        return (!isKeyword(name));
    }
    return false;
}