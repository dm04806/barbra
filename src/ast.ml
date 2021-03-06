(** AST types and helpers. *)

open Common
open Types

type meta = [ `Build of string
            | `Install of string
            | `Flag of string
            | `Patch of string
            | `Requires of string list ]

type dep = (string * string * string * meta list)
type repository = (string * string)

type ctxt =
    {
      version      : string;
      repositories : repository list;
      deps         : dep list
    }


let guess_archive s ~succ ~fail =
  let ext = Filename.check_suffix s in
  if ext ".tar.gz" || ext ".tgz" then
    succ `TarGz
  else if ext ".tar.bz2" || ext ".tbz" then
    succ `TarBzip2
  else if ext ".tar" then
    succ `Tar
  else
    fail ()

let to_package (_name, source, location, _meta) = match source with
  | "remote" ->
    guess_archive location
      ~succ:(fun x -> Remote (x, location))
      ~fail:(fun () ->
        Log.error "can't guess remote archive format: %S\n" source)
  | "remote-tar-gz"  -> Remote (`TarGz, location)
  | "remote-tar-bz2" -> Remote (`TarBzip2, location)
  | "remote-tar"     -> Remote (`Tar, location)
  | "local" ->
    guess_archive location
      ~succ:(fun x -> Local ((x :> local_type), location))
      ~fail:(fun () ->
        Log.error "can't guess local archive format: %S\n" source)
  | "local-tar-gz" -> Local (`TarGz, location)
  | "local-tar-bz2" -> Local (`TarBzip2, location)
  | "local-tar" -> Local (`Tar, location)
  | "local-dir" -> Local (`Directory, location)
  | "bundled-dir" -> Bundled (`Directory, location)
  | "bundled" ->
    guess_archive location
      ~succ:(fun x -> Bundled ((x :> local_type), location))
      ~fail:(fun () ->
        Log.error "can't guess bundle's archive format: %S\n" source)
  | "bundled-tar" -> Bundled (`Tar, location)
  | "bundled-tar-gz" -> Bundled (`TarGz, location)
  | "bundled-tar-bz2" -> Bundled (`TarBzip2, location)
  | "svn" | "csv" | "hg" | "git" | "bzr" | "darcs" ->
    VCS (vcs_type_of_string source, location)
  | "recipe" -> Recipe location
  | _ -> Log.error "unsupported package type: %S\n" source

let to_dep ((name, _source, _location, metas) as ast) =
  (* Note(superbobry): fold an assorted list of meta fields into
     three categories -- make targets, configure flags and patches;
     the order is preserved. *)
  let (build_cmd, install_cmd, flags, patches, requires) =
    List.fold_left metas
      ~init:("make", "make install", [], [], [])
      ~f:(fun (bc, ins, fs, ps, rs) meta -> match meta with
        | `Build bc -> (bc, ins, fs, ps, rs)
        | `Install ins -> (bc, ins, fs, ps, rs)
        | `Flag f ->
          (bc, ins, (String.nsplit f " ") @ fs, ps, rs)
        | `Patch p -> (bc, ins, fs, p :: ps, rs)
        | `Requires r -> (bc, ins, fs, ps, rs @ r)
    )
  in

  {
    name;
    package = to_package ast;
    install_cmd; build_cmd;
    requires; flags; patches;
  }
