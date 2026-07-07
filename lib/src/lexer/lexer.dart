/// KromScript Lexer - Tokenizes source code.
library;

import '../token/token.dart';

/// Lexer tokenizes KromScript source code.
class Lexer {
  final String _input;
  int _position = 0;
  int _readPosition = 0;
  String _ch = '';
  int _line = 1;
  int _column = 0;

  Token? _prevToken;

  Lexer(this._input) {
    _readChar();
  }

  void _readChar() {
    if (_readPosition >= _input.length) {
      _ch = '';
    } else {
      _ch = _input[_readPosition];
    }
    _position = _readPosition;
    _readPosition++;
    _column++;
  }

  String _peekChar() {
    if (_readPosition >= _input.length) {
      return '';
    }
    return _input[_readPosition];
  }

  Token nextToken() {
    _skipWhitespace();

    Token tok;
    final startColumn = _column;

    switch (_ch) {
      case '':
        tok = Token(TokenType.eof, '', line: _line, column: startColumn);
      case '\n':
        if (_shouldInsertSemicolon()) {
          tok = Token(TokenType.newline, '\n', line: _line, column: startColumn);
        } else {
          _line++;
          _column = 0;
          _readChar();
          return nextToken();
        }
        _line++;
        _column = 0;
      case '=':
        if (_peekChar() == '=') {
          _readChar();
          tok = Token(TokenType.eq, '==', line: _line, column: startColumn);
        } else if (_peekChar() == '>') {
          _readChar();
          tok = Token(TokenType.arrow, '=>', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.assign, '=', line: _line, column: startColumn);
        }
      case '+':
        if (_peekChar() == '=') {
          _readChar();
          tok = Token(TokenType.plusAssign, '+=', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.plus, '+', line: _line, column: startColumn);
        }
      case '-':
        if (_peekChar() == '=') {
          _readChar();
          tok = Token(TokenType.minusAssign, '-=', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.minus, '-', line: _line, column: startColumn);
        }
      case '*':
        if (_peekChar() == '=') {
          _readChar();
          tok = Token(TokenType.asteriskAssign, '*=', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.asterisk, '*', line: _line, column: startColumn);
        }
      case '/':
        if (_peekChar() == '/') {
          _skipLineComment();
          return nextToken();
        }
        if (_peekChar() == '*') {
          final hadNewline = _skipBlockComment();
          // A block comment that spans lines separates statements exactly like
          // the newlines it swallowed: re-emit one when ASI would have fired.
          if (hadNewline && _shouldInsertSemicolon()) {
            final t = Token(TokenType.newline, '\n', line: _line, column: _column);
            _prevToken = t;
            return t;
          }
          return nextToken();
        }
        if (_peekChar() == '=') {
          _readChar();
          tok = Token(TokenType.slashAssign, '/=', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.slash, '/', line: _line, column: startColumn);
        }
      case '%':
        tok = Token(TokenType.percent, '%', line: _line, column: startColumn);
      case '!':
        if (_peekChar() == '=') {
          _readChar();
          tok = Token(TokenType.notEq, '!=', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.not, '!', line: _line, column: startColumn);
        }
      case '<':
        if (_peekChar() == '=') {
          _readChar();
          tok = Token(TokenType.ltEq, '<=', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.lt, '<', line: _line, column: startColumn);
        }
      case '>':
        if (_peekChar() == '=') {
          _readChar();
          tok = Token(TokenType.gtEq, '>=', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.gt, '>', line: _line, column: startColumn);
        }
      case '&':
        if (_peekChar() == '&') {
          _readChar();
          tok = Token(TokenType.and, '&&', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.illegal, _ch, line: _line, column: startColumn);
        }
      case '|':
        if (_peekChar() == '|') {
          _readChar();
          tok = Token(TokenType.or, '||', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.illegal, _ch, line: _line, column: startColumn);
        }
      case '?':
        if (_peekChar() == '.') {
          _readChar();
          tok = Token(TokenType.safeAccess, '?.', line: _line, column: startColumn);
        } else if (_peekChar() == ':') {
          _readChar();
          tok = Token(TokenType.elvis, '?:', line: _line, column: startColumn);
        } else {
          tok = Token(TokenType.illegal, _ch, line: _line, column: startColumn);
        }
      case ',':
        tok = Token(TokenType.comma, ',', line: _line, column: startColumn);
      case ';':
        tok = Token(TokenType.semicolon, ';', line: _line, column: startColumn);
      case ':':
        tok = Token(TokenType.colon, ':', line: _line, column: startColumn);
      case '(':
        tok = Token(TokenType.lparen, '(', line: _line, column: startColumn);
      case ')':
        tok = Token(TokenType.rparen, ')', line: _line, column: startColumn);
      case '{':
        tok = Token(TokenType.lbrace, '{', line: _line, column: startColumn);
      case '}':
        tok = Token(TokenType.rbrace, '}', line: _line, column: startColumn);
      case '[':
        tok = Token(TokenType.lbracket, '[', line: _line, column: startColumn);
      case ']':
        tok = Token(TokenType.rbracket, ']', line: _line, column: startColumn);
      case '.':
        tok = Token(TokenType.dot, '.', line: _line, column: startColumn);
      case '"':
      case "'":
        final delimiter = _ch;
        final result = _readString(delimiter);
        final type = result.isTemplate ? TokenType.stringTemplate : TokenType.string;
        tok = Token(type, result.value, line: _line, column: startColumn);
      default:
        if (_isLetter(_ch)) {
          final ident = _readIdentifier();
          final type = Token.lookupIdent(ident);
          tok = Token(type, ident, line: _line, column: startColumn);
          _prevToken = tok;
          return tok;
        } else if (_isDigit(_ch)) {
          final num = _readNumber();
          tok = Token(TokenType.number, num, line: _line, column: startColumn);
          _prevToken = tok;
          return tok;
        } else {
          tok = Token(TokenType.illegal, _ch, line: _line, column: startColumn);
        }
    }

    _readChar();
    _prevToken = tok;
    return tok;
  }

  bool _shouldInsertSemicolon() {
    if (_prevToken == null) return false;
    return _prevToken!.type.canEndStatement;
  }

  void _skipWhitespace() {
    while (_ch == ' ' || _ch == '\t' || _ch == '\r') {
      _readChar();
    }
  }

  void _skipLineComment() {
    while (_ch != '\n' && _ch != '') {
      _readChar();
    }
  }

  /// Skips a `/* ... */` block comment (cur is '/', peek is '*').
  /// Returns true when the comment contained at least one newline.
  /// An unterminated comment simply runs to EOF.
  bool _skipBlockComment() {
    var hadNewline = false;
    _readChar(); // consume '*' (cur becomes '*')
    _readChar(); // move past '*'
    while (_ch != '') {
      if (_ch == '*' && _peekChar() == '/') {
        _readChar(); // move to '/'
        _readChar(); // move past '/'
        return hadNewline;
      }
      if (_ch == '\n') {
        hadNewline = true;
        _line++;
        _column = 0;
      }
      _readChar();
    }
    return hadNewline;
  }

  String _readIdentifier() {
    final start = _position;
    while (_isLetter(_ch) || _isDigit(_ch)) {
      _readChar();
    }
    return _input.substring(start, _position);
  }

  String _readNumber() {
    final start = _position;
    while (_isDigit(_ch)) {
      _readChar();
    }
    if (_ch == '.' && _isDigit(_peekChar())) {
      _readChar();
      while (_isDigit(_ch)) {
        _readChar();
      }
    }
    return _input.substring(start, _position);
  }

  ({String value, bool isTemplate}) _readString(String delimiter) {
    _readChar(); // skip opening delimiter
    final buffer = StringBuffer();
    var isTemplate = false;
    var braceDepth = 0;

    while (_ch != '' && (braceDepth > 0 || _ch != delimiter)) { // Run until delimiter at depth 0 or EOF
      if (_ch == '\\') {
        _readChar();
        switch (_ch) {
          case 'n': buffer.write('\n');
          case 't': buffer.write('\t');
          case 'r': buffer.write('\r');
          case '"': buffer.write('"');
          case "'": buffer.write("'");
          case '\\': buffer.write('\\');
          case '\$': buffer.write('\$');
          default:
            buffer.write('\\');
            buffer.write(_ch);
        }
      } else if (_ch == '\$' && _peekChar() == '{') {
        // Template expression detected
        isTemplate = true;
        braceDepth++;
        buffer.write('\$');
        buffer.write('{');
        _readChar(); // consume $
      } else if (braceDepth > 0) {
          // Inside interpolation
          if (_ch == '{') {
              braceDepth++;
              buffer.write(_ch);
          } else if (_ch == '}') {
              braceDepth--;
              buffer.write(_ch);
          } else if (_ch == '"' || _ch == "'") {
              // Skip string inside interpolation
              final quote = _ch;
              buffer.write(quote);
              _readChar();
              while (_ch != '' && _ch != quote) {
                  if (_ch == '\\') {
                      buffer.write('\\');
                      _readChar();
                  }
                  buffer.write(_ch);
                  _readChar();
              }
              buffer.write(_ch); // closing quote
          } else {
              buffer.write(_ch);
          }
      } else {
        buffer.write(_ch);
      }
      _readChar();
    }
    return (value: buffer.toString(), isTemplate: isTemplate);
  }

  bool _isLetter(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) || // A-Z
        (c >= 97 && c <= 122) || // a-z
        c == 95; // _
  }

  bool _isDigit(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return c >= 48 && c <= 57; // 0-9
  }
}
