import Foundation
import LanguageKit

/// Representative source snippets per supported language, for consumers'
/// tests (grammar smoke tests, capture assertions, concurrency exercises).
public enum SyntaxTestFixtures {
    /// The languages fixtures exist for (the 14 standard languages).
    public static var languages: [LanguageID] {
        Array(snippetsByLanguage.keys).sorted { $0.rawValue < $1.rawValue }
    }

    /// A representative snippet with declarations (functions/types), sized so
    /// both highlight and code-map queries produce captures.
    public static func snippet(for language: LanguageID) -> String? {
        snippetsByLanguage[language]
    }

    /// The minimal one-expression samples RepoPrompt's characterization tests
    /// pinned (enough to produce a parse tree, not necessarily captures).
    public static func minimalSnippet(for language: LanguageID) -> String? {
        minimalSnippetsByLanguage[language]
    }

    private static let snippetsByLanguage: [LanguageID: String] = [
        .swift: """
        import Foundation

        /// A greeter.
        struct Greeter {
            let id = 42
            func greet(name: String) -> String {
                return "hello " + name
            }
        }
        """,
        .javascript: """
        // point
        class Point {
          constructor(x) {
            this.x = x;
          }
        }

        function add(a, b) {
          return a + b;
        }
        """,
        .csharp: """
        using System;

        namespace Demo {
            public class Point {
                private int x = 1;
                public int Add(int a, int b) { return a + b; }
            }
        }
        """,
        .python: """
        import os

        class Point:
            def __init__(self, x):
                self.x = x

        def add(a, b):
            return a + b
        """,
        .c: """
        #include <stdio.h>

        struct point { int x; };

        int add(int a, int b) {
            return a + b;
        }
        """,
        .rust: """
        struct Point { x: i32 }

        impl Point {
            fn add(&self, y: i32) -> i32 { self.x + y }
        }

        fn main() {}
        """,
        .cpp: """
        class Point {
        public:
            int add(int a, int b) { return a + b; }
        private:
            int x = 0;
        };

        int main() { return 0; }
        """,
        .go: """
        package main

        type Point struct { X int }

        func add(a int, b int) int {
            return a + b
        }
        """,
        .java: """
        public class Point {
            private int x;
            public int add(int a, int b) { return a + b; }
        }
        """,
        .dart: """
        class Point {
          int x = 0;
          int add(int a, int b) => a + b;
        }

        void main() {}
        """,
        .typescript: """
        interface Shape { area(): number; }

        class Point implements Shape {
          constructor(private x: number) {}
          area(): number { return this.x; }
        }

        function add(a: number, b: number): number { return a + b; }
        """,
        .tsx: """
        function Widget(props: { label: string }) {
          return <div>{props.label}</div>;
        }

        class Store {
          get(): number { return 1; }
        }
        """,
        .php: """
        <?php
        class Point {
            public function add(int $a, int $b): int {
                return $a + $b;
            }
        }
        function greet(string $n): string { return $n; }
        """,
        .ruby: """
        class Point
          def add(a, b)
            a + b
          end
        end

        def greet(name)
          name
        end
        """,
    ]

    private static let minimalSnippetsByLanguage: [LanguageID: String] = [
        .swift: "let x = 1",
        .javascript: "function f() { return 1; }",
        .csharp: "class T { static void Main() { } }",
        .python: "def f():\n    return 1",
        .c: "int main(void) { return 0; }",
        .rust: "fn main() {}",
        .cpp: "int main() { return 0; }",
        .go: "package main\nfunc main() {}",
        .java: "class T { public static void main(String[] a) {} }",
        .dart: "void main() {}",
        .typescript: "function f(): void {}",
        .tsx: "const F = () => 1;",
        .php: "<?php function f() { return 1; } ?>",
        .ruby: "def f\n  1\nend",
    ]
}
