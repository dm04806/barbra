{
  open Parser

  let keywords = Hashtbl.create 9
  let () = List.iter (fun (kwd, token) -> Hashtbl.add keywords kwd token) [
    ("dep",  DEP);
    ("build", BUILD);
    ("flag", FLAG);
    ("patch", PATCH);
    ("install", INSTALL);
    ("requires", REQUIRES);
    ("repository", REPOSITORY);
    ("version", VERSION)
  ]
}

rule token = parse
  | [' ' '\t']     {token lexbuf}
  | '#' [^'\n']*   {token lexbuf}
  | '\n'           {Lexing.new_line lexbuf; token lexbuf}
  | ','            {COMMA}
  | eof            {EOF}
  | ['A'-'Z' 'a'-'z' '0'-'9' '-' '_']+ as lxm {
    let lxm = String.lowercase lxm in
    try
      Hashtbl.find keywords lxm
    with Not_found -> IDENT(lxm)
  }
  | '"' ([^'"']+ as lxm) '"' {VALUE(lxm)}
