import Foundation
import LanguageKit
import Testing
import TreeSitterCore
import TreeSitterStandardLanguages

/// The TypeScript/TSX code-map query keeps constants whose value is an arrow
/// function out of `variable.global` (they are captured as functions). That
/// must be decided from the value node itself: an arrow nested anywhere inside
/// another value (an IIFE, a call argument, an object member, a type) does not
/// make the constant a function. Expected sets match TreeSitterKit 0.3.0 for
/// every value that is not itself an arrow function.
@Suite struct CodeMapGlobalValueTests {
    private func globals(_ source: String, _ language: LanguageID) async throws -> [String] {
        let parser = try SyntaxParser.standard()
        let captures = try await parser.codeMapCaptures(in: source, language: language)
        let text = source as NSString
        return captures.filter { $0.name == "variable.global" }.map { text.substring(with: $0.range) }
    }

    /// An immediately invoked arrow: the value is a call, a real constant.
    @Test(arguments: [LanguageID.typescript, .tsx])
    func immediatelyInvokedArrowIsAGlobal(language: LanguageID) async throws {
        let source = """
        export const CONFIG = (() => {
            const secret = 'hidden';
            return { public: true };
        })();
        const LOCAL = (() => 1)();
        """
        #expect(try await globals(source, language) == ["CONFIG", "LOCAL"])
    }

    /// `forwardRef(function …) as <T>(…) => JSX.Element`: the value is an
    /// `as_expression`; only its type spells `=>`.
    @Test func forwardRefCastToAGenericFunctionTypeIsAGlobal() async throws {
        let source = """
        export const List = forwardRef(function List<T>(
            { items }: ListProps<T>,
            ref: ForwardedRef<HTMLUListElement>
        ) {
            return <ul ref={ref}>{items.map((item) => <li>{item}</li>)}</ul>;
        }) as <T>(props: ListProps<T>) => JSX.Element;
        export const Box = forwardRef(function Box<E extends React.ElementType = "div">(
            props: BoxProps<E>,
            ref: PolymorphicRef<E>
        ) {
            return <div ref={ref} />;
        }) as <E extends React.ElementType = "div">(
            props: BoxProps<E>
        ) => JSX.Element;
        """
        #expect(try await globals(source, .tsx) == ["List", "Box"])
    }

    /// Values that are themselves arrow functions (plain, async, generic,
    /// parenthesized) are functions, not globals (the 0.3.1 behavior the app
    /// accepted).
    @Test(arguments: [LanguageID.typescript, .tsx])
    func arrowValuedConstantsAreNotGlobals(language: LanguageID) async throws {
        let source = """
        export const plain = (x: number) => x + 1;
        export const asyncArrow = async (x: number): Promise<number> => x;
        export const wrapped = ((x: number): number => x + 1);
        const local = (s: string) => s.trim();
        const annotated: (x: number) => number = (x) => x;
        export const KEEP = 1;
        """
        #expect(try await globals(source, language) == ["KEEP"])
    }

    /// Near misses: the value is not an arrow function, so the constant is a
    /// global whatever arrows or `=>` text its value or annotation contains.
    @Test(arguments: [LanguageID.typescript, .tsx])
    func valuesContainingArrowsAreGlobals(language: LanguageID) async throws {
        let source = """
        export const cb = useCallback(() => {}, []);
        const doubled = arr.map(x => x * 2);
        export const handlers = { onClick: () => {}, onKey(e: Event) {} };
        export const fn2: (x: number) => number = compute;
        export const ARROW = "=>";
        export const fe = function named(x: number): number { return x; };
        """
        #expect(try await globals(source, language) == ["cb", "doubled", "handlers", "fn2", "ARROW", "fe"])
    }

    /// A HOC wrapping an arrow is captured as a function by the HOC rule and,
    /// as on 0.3.0, also as a global (its value is a call).
    @Test func hocWrappingAnArrowIsStillAGlobal() async throws {
        let source = """
        export const Button = forwardRef<HTMLButtonElement, Props>(
            (props, ref) => <button ref={ref} {...props} />
        );
        export const Card = memo((props: CardProps) => <div />);
        """
        #expect(try await globals(source, .tsx) == ["Button", "Card"])
    }

    private func functions(_ source: String, _ language: LanguageID) async throws -> [String] {
        let parser = try SyntaxParser.standard()
        let captures = try await parser.codeMapCaptures(in: source, language: language)
        let text = source as NSString
        return captures.filter { $0.name == "function.definition" }.map { text.substring(with: $0.range) }
    }

    /// A comment is a named child of the parentheses. A parenthesized value
    /// that holds a comment and a non-arrow is a global (as on 0.3.0 and
    /// 0.3.1), reported once; one that holds a comment and an arrow is a
    /// function, not a global.
    @Test(arguments: [LanguageID.typescript, .tsx])
    func parenthesizedValuesWithCommentsAreClassifiedByTheirExpression(language: LanguageID) async throws {
        let source = """
        export const cmt = ( /* note */ someCall() );
        export const cmt2 = (someCall() /* trailing */);
        const localCmt = ( /* c */ compute() );
        export const commentedArrow = ( // why
            () => 1
        );
        const localCommentedArrow = ( /* c */ (x: number) => x );
        const twoComments = ( /* x */ /* y */ (z: number) => z );
        """
        #expect(try await globals(source, language) == ["cmt", "cmt2", "localCmt"])
        #expect(try await functions(source, language) == ["commentedArrow", "localCommentedArrow", "twoComments"])
    }

    /// Prettier's layout for a JSX constant with a leading comment.
    @Test func parenthesizedJSXWithALeadingCommentIsAGlobal() async throws {
        let source = """
        export const Hero = (
          // marketing hero
          <section className="hero" />
        );
        """
        #expect(try await globals(source, .tsx) == ["Hero"])
    }
}
