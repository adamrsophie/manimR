"""Highlight code with Pygments for manimR's Code(), as upstream's Code does.

Usage: python pygments_tokens.py CODE_FILE LANGUAGE STYLE FILENAME
LANGUAGE and FILENAME may be empty. Prints the style colors, the lexer name,
the text Pygments highlights (hex encoded UTF-8) and one line per colored
token: start, end (character offsets) and color.
"""

import sys

from pygments import lex
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name, guess_lexer, guess_lexer_for_filename
from pygments.styles import get_all_styles
from pygments.token import Text


def main() -> None:
    if sys.argv[1] == "--styles":
        print("\n".join(get_all_styles()))
        return
    code_file, language, style, filename = sys.argv[1:5]
    with open(code_file, encoding="utf-8") as f:
        code = f.read()
    if language:
        lexer = get_lexer_by_name(language)
    elif filename:
        lexer = guess_lexer_for_filename(filename, code)
    else:
        lexer = guess_lexer(code)
    selected = HtmlFormatter(style=style, noclasses=True, cssclasses="").style
    tokens = list(lex(code, lexer))
    text = "".join(value for _, value in tokens)
    print("BG\t" + (selected.background_color or ""))
    print("FG\t" + (selected.style_for_token(Text).get("color") or ""))
    print("LN\t" + str(selected.line_number_color or ""))
    print("LEXER\t" + lexer.name)
    print("TEXT\t" + text.encode("utf-8").hex())
    pos = 0
    for ttype, value in tokens:
        color = selected.style_for_token(ttype).get("color")
        if color:
            print(f"{pos}\t{pos + len(value)}\t#{color}")
        pos += len(value)


if __name__ == "__main__":
    main()
