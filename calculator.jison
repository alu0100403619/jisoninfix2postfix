/* description: 
   Translates infix expressions to postfix. 
   Implements functions and function calls
*/

%{

var symbolTables = [{}];
var scope = 0; 
var symbolTable = symbolTables[scope];

function getFormerScope() {
   scope--;
   symbolTable = symbolTables[scope];
}

function makeNewScope() {
   scope++;
   symbolTables[scope] = {};
   symbolTable = symbolTables[scope];
}

function findSymbol(x) {
  var f;
  var s = scope;
  do {
    f = symbolTables[s][x];
    s--;
  } while (s >= 0 && !f);
  return f;
}

var myCounter = 0;
function newLabel(x) {
  return String(x)+myCounter++;
}

function translateIf(e, s) {
  var endif = newLabel('endif');
  return e+unary("jmpz "+endif, 'jump')+s+label(endif, 'jump'); 
}

function translateIfElse(e, s1, s2) {
  var lendif = newLabel('endif');
  var lelse  = newLabel('else');
  return (e+
       unary("jmpz "+lelse,'jump')+
       s1+
       unary("jmp "+lendif,'jump')+
       label(lelse, 'jump')+
       s2+
       label(lendif, 'jump')); 
}

function binary(x,y,op) {
  return x+" "+y+"\t"+op+"\n";
}

function unary(x, cl) {
  var pr = ''; 
  var po = '';
  if (cl) {
    pr = "<span class='"+cl+"'>";
    po = "</span>";
  }
  return "\t"+pr+x+po+"\n";
}

function label(x, cl) {
  var pr = ''; 
  var po = '';
  if (cl) {
    pr = "<span class='"+cl+"'>";
    po = "</span>";
  }
  return pr+":"+x+po+"\n"; 
}

function functionCall(name, arglist) {
  var info = findSymbol(name);
  if (!info || info.type != 'FUNC') {
    throw new Error("Can't call '"+name+"' ");
  }
  else if(arglist.length != info.arity) {
    throw new Error("Can't call '"+name+"' with "+arglist.length+
                    " arguments. Expected "+info.arity+" arguments.");
  }
  return arglist.join('')+unary("call "+":"+name,"jump");
}
 
function translateFunction(name, parameters, statements) {

  symbolTable[name] = $.extend({}, symbolTable[name], { 
    parameters: parameters, 
    arity: parameters.length,
    statements: statements 
  });

  return label(name+"\targs "+parameters.map(function(x) { return ':'+x; }).join(','), 'jump')+
         statements.join('')+unary('return', 'jump'); 
}

%}

/* operator associations and precedence */

%token IF ELSE THEN DEF PI E ID NUMBER EOF

%nonassoc ID
%nonassoc "("

%left THEN
%right ELSE

%right "="
%left "<=" ">=" "==" "!=" "<" ">" 
%left "+" "-"
%left "*" "/"
%left "^"
%left "!"
%right "%"
%left UMINUS

%start prog

%% /* language grammar */
prog
    : decs statements EOF
        { 
          var decs = $decs.join('');
          var sts = label("main:",'jump')+$statements.join("");
          console.log(decs);
          console.log(sts);
          return decs+sts;
        }
    ;

decs
    : /* empty */ { $$ = []; }
    | decs dec    { $$ = $1; $$.push($2); }
    ;

dec 
    : DEF functionname  optparameters "{" statements "}" 
                  { 
                     getFormerScope();

                     $$ = translateFunction($functionname, 
                                            $optparameters, 
                                            $statements); 
                  }
    ;

functionname
    : ID 
                  {
                     if (symbolTable[$ID]) 
                       throw new Error("Function "+$ID+" defined twice");
                     symbolTable[$ID] = { type: 'FUNC'};

                     makeNewScope();

                     $$ = $ID;
                  }
    ;

optparameters
    : /* empty */            { $$ = []; }
    | parameters
    | "(" parameters ")"     { $$ = $parameters; }
    ;
        
parameters
    : ID                      { 
                                 $symbolTable[$ID] = { type : 'PARAM' };
                                 $$ = [ $ID ]; 
                              }
    | parameters "," ID       { 
                                 $symbolTable[$ID] = { type : 'PARAM' };
                                 $$ = $1; 
                                 $$.push($ID); 
                               }
    ;

statements
    : s  
        { $$ = $1? [ $1 ] : []; }
    | statements ";" s
        { $$ = $1;
          if ($3) $$.push($3); 
          console.log($$);
        }
    ;

s
    : /* empty */ { $$ = ''; }
    | e
    | IF e THEN s
        { $$ = translateIf($e, $s); }
    | IF e THEN s ELSE s
        { $$ = translateIfElse($e, $s1, $s2); }
    ;

e
    : ID "=" e
        { 
           symbolTable[$ID] = "VAR"; 
           $$ = binary($3,unary("&"+$1), "=");
        }
    | PI "=" e 
        { throw new Error("Can't assign to constant 'π'"); }
    | E "=" e 
        { throw new Error("Can't assign to math constant 'e'"); }
    | e "<=" e
        { $$ = binary($1,$3, "<=");}
    | e ">=" e
        { $$ = binary($1,$3, ">=");}
    | e "<" e
        { $$ = binary($1,$3, "<");}
    | e ">" e
        { $$ = binary($1,$3, ">");}
    | e "==" e
        { $$ = binary($1,$3, "==");}
    | e "+" e
        { $$ = binary($1,$3, "+");}
    | e "*" e
        { $$ = binary($1,$3, "*");}
    | e "/" e
        { $$ = binary($1,$3, "/");}
    | "(" e ")"
        { $$ = $2;}
    | ID "(" optarglist ")"
        { $$ = functionCall($ID, $optarglist); }
    | NUMBER
        { $$ = unary($NUMBER);}
    | E
        { $$ = unary(Math.E);}
    | PI
        { $$ = unary(Math.PI);}
    | ID 
        { 
          if (symbolTable[$ID] && symbolTable[$ID].type == 'PARAM') {
            $$ = unary('$'+$ID);
          }
          else {
            $$ = unary($ID);
          }
        }
    ;

optarglist 
    : /* empty */  {  $$ = []; }
    | arglist      
    ;

arglist
    : e               { $$ = [ $e ]; }
    | arglist ',' e   { $$ = $arglist; $$.push($e); }
    ;
