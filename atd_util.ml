

let read_lexbuf
    ?(expand = false) ?keep_poly ?(xdebug = false)
    ?(inherit_fields = false)
    ?(inherit_variants = false)
    ?(pos_fname = "")
    ?(pos_lnum = 1)
    lexbuf =

  Atd_lexer.init_fname lexbuf pos_fname pos_lnum;
  let head, body = Atd_parser.full_module Atd_lexer.token lexbuf in
  Atd_check.check body;
  let body =
    if inherit_fields || inherit_variants then
      Atd_inherit.expand_module_body ~inherit_fields ~inherit_variants body
    else
      body
  in
  let body =
    if expand then Atd_expand.expand_module_body ?keep_poly ~debug: xdebug body
    else body
  in
  head, body

let read_channel
    ?expand ?keep_poly ?xdebug ?inherit_fields ?inherit_variants
    ?pos_fname ?pos_lnum
    ic =
  let lexbuf = Lexing.from_channel ic in
  let pos_fname =
    if pos_fname = None && ic == stdin then
      Some "<stdin>"
    else
      pos_fname
  in
  read_lexbuf ?expand ?keep_poly ?xdebug
    ?inherit_fields ?inherit_variants ?pos_fname ?pos_lnum lexbuf

let load_file
    ?expand ?keep_poly ?xdebug ?inherit_fields ?inherit_variants
    ?pos_fname ?pos_lnum
    file =
  let ic = open_in file in
  let finally () = close_in_noerr ic in
  try
    let pos_fname =
      match pos_fname with
          None -> Some file
        | Some _ -> pos_fname
    in
    let ast =
      read_channel ?expand ?keep_poly ?xdebug ?inherit_fields ?inherit_variants
        ?pos_fname ?pos_lnum ic
    in
    finally ();
    ast
  with e ->
    finally ();
    raise e

let load_string
    ?expand ?keep_poly ?xdebug ?inherit_fields ?inherit_variants
    ?pos_fname ?pos_lnum
    s =
  let lexbuf = Lexing.from_string s in
  read_lexbuf ?expand ?keep_poly ?xdebug
    ?inherit_fields ?inherit_variants ?pos_fname ?pos_lnum lexbuf

module Tsort = Atd_tsort.Make (
  struct
    type t = string
    let compare = String.compare
    let to_string s = s
  end
)

let tsort l0 =
  let ignorable = [ "unit"; "bool"; "int"; "float"; "string"; "abstract" ] in
  let l =
    List.map (
      fun def ->
        let `Type (loc, (name, _, _), x) = def in
        let deps = Atd_ast.extract_type_names ~ignorable x in
        (name, deps, def)
    ) l0
  in
  List.rev (Tsort.sort l)
