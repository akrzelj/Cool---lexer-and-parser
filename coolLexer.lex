%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

int razinaKomentara=0;

%}

RAZMAK	    [ \f\r\t\v]
BROJ		[0-9]+
TIP		[A-Z][a-zA-Z0-9_]*
OBJEKT		[a-z][a-zA-Z0-9_]*
POSEBNI_ZNAKOVI		"+"|"-"|"*"|"/"|"~"|"<"|"="|"("|")"|"{"|"}"|";"|":"|"."|","|"@"
POSEBNI_ZNAKOVI_NEVALJANI		"`"|"!"|"#"|"$"|"%"|"^"|"&"|"_"|"["|"]"|"|"|[\\]|">"|"?"

%x KOMENTAR STRING ESCAPE

%%

"=>"			return DARROW;
"<-"			return ASSIGN;
"<="			return LE;

(?i:class)		return CLASS;
(?i:inherits)	return INHERITS;
(?i:else)		return ELSE;
(?i:fi)			return FI;
(?i:if)			return IF;
(?i:not)		return NOT;
(?i:in)			return IN;
(?i:let)		return LET;
(?i:case)		return CASE;
(?i:esac)		return ESAC;
(?i:of)			return OF;
(?i:new)		return NEW;
(?i:isvoid)		return ISVOID;
(?i:loop)		return LOOP;
(?i:pool)		return POOL;
(?i:then)		return THEN;
(?i:while)		return WHILE;

(t)([rR][uU][eE])	{
			    cool_yylval.boolean = true;
			    return BOOL_CONST;
}

(f)(?i:alse) {
			    cool_yylval.boolean = false;
			    return BOOL_CONST;
}


 /*
  * ###################################################################3
  * Rukovanje posebnim znakovima
  */
{POSEBNI_ZNAKOVI} {
                return int(yytext[0]);
}

{POSEBNI_ZNAKOVI_NEVALJANI} {
				cool_yylval.error_msg = yytext;
				return ERROR;
}
	
 /*
  * #####################################################################
  * BROJ, TIP, OBJEKT
  */
{BROJ} {
		    cool_yylval.symbol = inttable.add_string(yytext);
			return INT_CONST;
}

{TIP}	{
			cool_yylval.symbol = idtable.add_string(yytext);
			return TYPEID;
}

{OBJEKT}|(self) {
				    cool_yylval.symbol = idtable.add_string(yytext);
				    return OBJECTID;
}

 /*
  * ###################################################################
  *  Rukovanje escapeanim karakterima
  */

<ESCAPE>[\n|"] {
                    BEGIN(INITIAL);
}

<ESCAPE>[^\n|"] {

}

 /*
  * ###################################################################3
  * Rukovanje komentarima
  */

"--"(.)* {

}

"*)" {
		cool_yylval.error_msg = "Pronadjena zatvarajuca zagrada bez otvarajuce";
		return ERROR;
}

"(*" {
		++razinaKomentara;
		BEGIN(KOMENTAR);				
}

<KOMENTAR>"(*" {
                    ++razinaKomentara;
}

<KOMENTAR>\n {
                ++curr_lineno;
}

<KOMENTAR>({RAZMAK}+)|(.) {

}

<KOMENTAR><<EOF>> {
				        BEGIN(INITIAL);
				        if (razinaKomentara > 0) {
					        cool_yylval.error_msg = "EOF pronadjen u komentaru";
					        razinaKomentara = 0;
					        return ERROR;
				        }
}

<KOMENTAR>"*)" {
				    --razinaKomentara;
				    if (razinaKomentara == 0) {
					    BEGIN(INITIAL);
                    } else if (razinaKomentara<0) {
					    cool_yylval.error_msg = "Pronadjena zatvarajuca zagrada bez otvarajuce";
					    razinaKomentara = 0;
					    BEGIN(INITIAL);
					    return ERROR;
				    }
}


 /*
  * ###################################################################
  *  Rukovanje stringovima
  */
"\"" {
		BEGIN(STRING);
		string_buf_ptr = string_buf;
}

<STRING>"\""  {
				if (string_buf_ptr - string_buf > MAX_STR_CONST-1) {
					*string_buf = '\0';
					cool_yylval.error_msg = "String je duzi od dozvoljenoga";
					BEGIN(ESCAPE);
					return ERROR;
				}

				*string_buf_ptr = '\0';
				cool_yylval.symbol = stringtable.add_string(string_buf);
				BEGIN(INITIAL);
				return STR_CONST;
}

<STRING><<EOF>>	{
				cool_yylval.error_msg = "EOF pronadjen u stringu";
				BEGIN(INITIAL);
				return ERROR;
}

<STRING>\0 {
				*string_buf = '\0';
				cool_yylval.error_msg = "String sadrzi null";
				BEGIN(ESCAPE);
				return ERROR;
}

<STRING>\n {
				*string_buf = '\0';
				BEGIN(INITIAL);
				cool_yylval.error_msg = "String nije zavrsen";
				return ERROR;
}

<STRING>"\\n" {
                *string_buf_ptr++ = '\n';
}

<STRING>"\\t" {
                *string_buf_ptr++ = '\t';
}

<STRING>"\\b" {
                *string_buf_ptr++ = '\b';
}

<STRING>"\\f" {
                *string_buf_ptr++ = '\f';
}

<STRING>"\\"[^\0] {
                *string_buf_ptr++ = yytext[1];
}

<STRING>. {
            *string_buf_ptr++ = *yytext;
}

 /*
  * ###################################################################
  *  Rukovanje preostalim stvarima
  */
	
 /*
  * Nova linija - samo povecal curr_lineno
  */
\n {
        curr_lineno++;
}

 /*
 * Razmak prepoznaj ali ne radi nista
 */
{RAZMAK}+ {

}

 /*
  * Kada se nista ne podudari baci error
  */
.		{
			cool_yylval.error_msg = yytext;
			return ERROR;
		}

%%