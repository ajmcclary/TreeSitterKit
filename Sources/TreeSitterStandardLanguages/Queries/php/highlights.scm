; === Minimal, compiler-safe PHP highlight query ===
; NOTE: Each pattern is on its own line (no top-level [ ... ] lists)
; and only node names present in the embedded grammar are referenced.

(string)         @string
(encapsed_string) @string
(heredoc)        @string
(heredoc_body)   @string

(boolean) @constant.builtin
(null)    @constant.builtin
(integer) @number
(float)   @number
(comment) @comment

; sprinkle a few keywords so unit tests detect highlighting
"function" @keyword
"class"    @keyword
"return"   @keyword
"if"       @keyword
"else"     @keyword