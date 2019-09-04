// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

enum Token {
	EOF            // EndMarker

  //General Tokens
	NAME
  NUMBER
	STRING
	STR_INTER      // 'name=$user.name'
	CHAR           // `A`
  INDENT
  DEDENT
	NEWLINE

  //Structural Operators
  DOT            // .
  COMMA          // ,
	SEMICOLON      // ;
	COLON          // :
  LCBR           // {}
	RCBR
	LPAR           // ()
	RPAR
	LSBR           // []
	RSBR
  //Mathematical Operators
  PLUS           // +
	MINUS          // -
	STAR           // *
	SLASH          // /
	PERCENTAGE     // %
	STSTAR				 // **
  // Logical Operators
	XOR            // ^
	PIPE           // |
	INC            // ++
	DEC            // --
	AND            // &&
	L_OR           // ||
	NOT            // !
	BIT_NOT        // ~
  LEFT_SHIFT     // <<
  RIGHT_SHIFT    // >>

  // Comparison Operators
	EQEQUAL        // ==
	NOTEQUAL       // != , <>
	GREATEREQUAL   // >=
	LESSEQUAL      // <=
  GREATER        // >
  LESSER         // <

  // Symbols
  QUESTION       // ?
  AMPER          // &
	HASH           // #
	DOLLAR         // $
  AT             // @
	ARROW          // =>
  BSLASH         // \

	// Assignment Operators
	ASSIGN         // =
	DECL_ASSIGN    // :=
	PLUS_ASSIGN    // +=
	MINUS_ASSIGN   // -=
	SLASH_ASSIGN   // /=
	STAR_ASSIGN    // *=
	XOR_ASSIGN     // ^=
	PER_ASSIGN     // %=
	OR_ASSIGN      // |=
	AND_ASSIGN     // &=
  AT_ASSIGN      // @=
	RIGHT_SHIFT_ASSIGN     // >>=
	LEFT_SHIFT_ASSIGN      // <<=

	// Comments
	SLINE_COMMENT
	MLINE_COMMENT_START
	MLINE_COMMENT_END

	NEWLINE

  TYPE_IGNORE
  TYPE_COMMENT
  <ERRORTOKEN>
  <COMMENT>

  OP
  AWAIT
  ASYNC
  <ENCODING>
  <N_TOKENS>

	// keywords
  keywords_top
	key_as
	key_assert
	key_atomic
	key_break
	key_case
	key_const
	key_continue
	key_default
	key_defer
	key_else
	key_else_if
	key_embed
	key_enum
	key_false
	key_for
	key_function
	key_global
	key_go
	key_goto
	key_if
	key_import
	key_import_const
	key_in
	key_interface
	key_match
	key_module
	key_mutable
	key_public
	key_private
	key_return
	key_select
	key_size
	key_sizeof
	key_static
	key_struct
	key_switch
	key_true
	key_type
	key_typeof
  key_union
	keywords_bottom
}

// Generates a map with keywords' string values: Keywords['return'] == .key_return

fn build_keys() map[string]int {
	mut res := map[string]int{}
	for tk := int(Token.keywords_top) + 1; tk < int(Token.keywords_bottom); tk++ {
		key := TokenStr[tk]
		res[key] = int(tk)
	}
	return res
}

// TODO remove once we have `enum Token { name('name') if('if') ... }`
fn build_token_str() []string {
	mut l := [''; NoOfTokens]
	l[Token.keywords_top] = ''
	l[Token.keywords_bottom] = ''
	l[Token.EOF] = '.EOF'
	l[Token.NAME] = '.NAME'
	l[Token.NUMBER] = '.NUMBER'
	l[Token.STRING] = '.STRING'
	l[Token.CHAR] = '.chartk'

  l[Token.DOT] = '.'
	l[Token.DOTDOT] = '..'
  l[Token.COMMA] = ','
  l[Token.SEMICOLON] = ';'
  l[Token.COLON] = ':'
  l[Token.LCBR] = '{'
	l[Token.RCBR] = '}'
	l[Token.LPAR] = '('
	l[Token.RPAR] = ')'
	l[Token.LSBR] = '['
	l[Token.RSBR] = ']'

	l[Token.PLUS] = '+'
	l[Token.MINUS] = '-'
	l[Token.STAR] = '*'
	l[Token.SLASH] = '/'
	l[Token.PERCENTAGE] = '%'
	l[Token.STSTAR] = '**'

	l[Token.XOR] = '^'
  l[Token.PIPE] = '|'
  l[Token.INC] = '++'
	l[Token.DEC] = '--'
  l[Token.AND] = '&&'
	l[Token.L_OR] = '||'
	l[Token.NOT] = '!'
	l[Token.BIT_NOT] = '~'
  l[Token.LEFT_SHIFT] = '<<'
	l[Token.RIGHT_SHIFT] = '>>'

  l[Token.EQEQUAL] = '=='
	l[Token.NOTEQUAL] = '!='
  l[Token.GREATEREQUAL] = '>='
	l[Token.LESSEQUAL] = '<='
	l[Token.GREATER] = '>'
	l[Token.LESSER] = '<'

  l[Token.QUESTION] = '?'
  l[Token.AMPER] = '&'
	l[Token.HASH] = '#'
	l[Token.DOLLAR] = '$'
	l[Token.AT] = '@'
	l[Token.ARROW] = '=>'
	l[Token.BSLASH] = '\'

	l[Token.ASSIGN] = '='
	l[Token.DECL_ASSIGN] = ':='
	l[Token.PLUS_ASSIGN] = '+='
	l[Token.MINUS_ASSIGN] = '-='
	l[Token.SLASH_ASSIGN] = '/='
	l[Token.STAR_ASSIGN] = '*='
	l[Token.XOR_ASSIGN] = '^='
	l[Token.PER_ASSIGN] = '%='
	l[Token.OR_ASSIGN] = '|='
	l[Token.AND_ASSIGN] = '&='
	l[Token.AT_ASSIGN] = '@='
  l[Token.RIGHT_SHIFT_ASSIGN] = '>>='
	l[Token.LEFT_SHIFT_ASSIGN] = '<<='

	l[Token.SLINE_COMMENT] = '//'
	l[Token.MLINE_COMMENT_START] = '/*'
	l[Token.MLINE_COMMENT_END] = '*\'
	l[Token.NEWLINE] = 'NL'

	l[Token.key_as] = 'as'
	l[Token.key_assert] = 'assert'
	l[Token.key_atomic] = 'atomic'
	l[Token.key_break] = 'break'
	l[Token.key_case] = 'case'
	l[Token.key_const] = 'const'
	l[Token.key_continue] = 'continue'
	l[Token.key_default] = 'default'
	l[Token.key_defer] = 'defer'
	l[Token.key_else] = 'else'
	l[Token.key_else_if] = 'or'
	l[Token.key_embed] = 'embed'
	l[Token.key_enum] = 'enum'
	l[Token.key_false] = 'false'
	l[Token.key_for] = 'for'
	l[Token.key_function] = 'fn'
	l[Token.key_global] = 'global'
	l[Token.key_go] = 'go'
	l[Token.key_goto] = 'goto'
	l[Token.key_if] = 'if'
	l[Token.key_import] = 'import'
	l[Token.key_import_const] = 'import_const'
	l[Token.key_in] = 'in'
	l[Token.key_interface] = 'interface'
	l[Token.key_match] = 'match'
	l[Token.key_module] = 'module'
	l[Token.key_mutable] = 'mut'
	l[Token.key_public] = 'public'
	l[Token.key_private] = 'private'
	l[Token.key_return] = 'return'
	l[Token.key_select] = 'select'
	l[Token.key_size] = 'size'
	l[Token.key_sizeof] = 'sizeof'
	l[Token.key_static] = 'static'
	l[Token.key_struct] = 'struct'
	l[Token.key_switch] = 'switch'
	l[Token.key_true] = 'true'
	l[Token.key_type] = 'type'
	l[Token.key_typeof] = 'typeof'
	l[Token.key_union] = 'union'
	return l
}

const (
	NoOfTokens = 140
	TokenStr = build_token_str()
	KEYWORDS = build_keys()
)

fn key_to_token(key string) Token {
	a := Token(KEYWORDS[key])
	return a
}

fn is_key(key string) bool {
	return int(key_to_token(key)) > 0
}

fn (t Token) str() string {
	return TokenStr[int(t)]
}

const (
	DeclTokens = [
		Token.key_enum , Token.key_interface , Token.key_function ,
		Token.key_struct , Token.key_type , Token.key_const ,
		Token.key_import , Token.key_import_const , Token.key_public ,
		Token.key_private , Token.EOF , Token.key_global
	]
)

fn (t Token) is_decl() bool {
	// Previously:-
	//return t == .key_enum || t == .key_interface || t == .key_function ||
	//t == .key_struct || t == .key_type ||
	//t == .key_const || t == .key_import_const || t == .key_public || t == .eof ||
	//t == .key_private || t == .key_global
	// Now:-
	return t in DeclTokens

}

const (
	AssignTokens = [
		Token.ASSIGN , Token.DECL_ASSIGN , Token.PLUS_ASSIGN ,
		Token.MINUS_ASSIGN , Token.SLASH_ASSIGN , Token.STAR_ASSIGN,
		Token.XOR_ASSIGN , Token.PER_ASSIGN , Token.OR_ASSIGN ,
		Token.AND_ASSIGN , Token.AT_ASSIGN , Token.RIGHT_SHIFT_ASSIGN ,
		Token.LEFT_SHIFT_ASSIGN
	]
)

fn (t Token) is_assign() bool {
	return t in AssignTokens
}

fn (t []Token) contains(val Token) bool {
	for tt in t {
		if tt == val {
			return true
		}
	}
	return false
}
