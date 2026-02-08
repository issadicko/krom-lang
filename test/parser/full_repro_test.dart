import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('Parser - Full output_raw.ks reproduction', () {
    test('should parse QuickAction function correctly', () {
      final source = '''
fn QuickAction(iconName, label, bgColor, onTap) {
  return Box({ borderRadius: 16, width: 85, height: 85, color: "white" }, 
    InkWell({ onTap: onTap, borderRadius: 12 }, 
      Column({ spacing: 8, mainAxisAlignment: "center" }, [
        Box({ width: 42, height: 42, color: bgColor, borderRadius: 16, alignment: "center" }, 
          Icon(iconName, { size: 20, color: "white" })
        ),
        Text(label, { fontSize: 14, color: "black" })
      ])
    )
  )
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();
      expect(parser.errors(), isEmpty);
    });

    test('should parse TransactionCard function correctly', () {
      final source = '''
fn TransactionCard(tx) {
  let iconName = "arrow_forward"
  if (tx.type != "income") {
    iconName = "arrow_back"
  }
  
  return Box({ padding: 16, borderRadius: 12, color: "white", borderColor: "#E0E0E0" }, 
    Row({ crossAxisAlignment: "center", spacing: 12 }, [
      Box({ width: 44, height: 44, borderRadius: 22, color: getTransactionColor(tx.type) + "20" }, 
        Box({ alignment: "center" }, 
          Icon(iconName, { size: 20, color: getTransactionColor(tx.type) })
        )
      ),
      Expanded({}, 
        Column({ crossAxisAlignment: "start", spacing: 4 }, [
          Text(tx.title, { fontSize: 16, fontWeight: "bold", color: "black" }),
          Text(tx.date, { fontSize: 12, color: "grey" })
        ])
      ),
      Text(formatMoney(tx.amount), { fontSize: 16, fontWeight: "bold", color: getTransactionColor(tx.type) })
    ])
  )
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();
      expect(parser.errors(), isEmpty);
    });

    test('should parse multiple functions together', () {
      final source = '''
fn QuickAction(iconName, label, bgColor, onTap) {
  return Box({ borderRadius: 16 }, 
    Column({ spacing: 8 }, [
      Icon(iconName, { size: 20 }),
      Text(label, { fontSize: 14 })
    ])
  )
}

fn TransactionCard(tx) {
  return Box({ padding: 16 }, 
    Row({ spacing: 12 }, [
      Box({ width: 44 }, Icon("x", { size: 20 })),
      Text(tx.title, { fontSize: 16 })
    ])
  )
}

fn build() {
  return Column([
    ScrollView({ direction: "horizontal" }, 
      Row({ spacing: 16 }, [
        QuickAction("cart", "Achats", colors.purple, "onShop"),
        QuickAction("home", "Maison", colors.warning, "onHome")
      ])
    ),
    Text("done")
  ])
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();
      
      if (parser.errors().isNotEmpty) {
        print('ERRORS: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });
  });
}
