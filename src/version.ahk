; ---------------------------------------------------------------------------
; Version. CI overwrites this file from the git tag before compiling; the
; values here are development defaults.
;
; The Ahk2Exe directives stamp the version into the compiled exe's metadata.
; AppVersion is a super-global so class methods can read it without
; redeclaration (About tab / future updater).
; ---------------------------------------------------------------------------

;@Ahk2Exe-SetVersion 0.0.0
;@Ahk2Exe-SetProductVersion 0.0.0

global AppVersion := "v0.0.0"
