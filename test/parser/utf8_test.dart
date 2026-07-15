import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('Parser - UTF-8 character handling', () {
    test('should parse string with É accent character', () {
      final source = '''
fn test() {
  return Column([
    Text("Épargne"),
    Text("More")
  ])
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();

      if (parser.errors().isNotEmpty) {
        print('FAILED: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });

    test('should parse complex nested with É inside', () {
      final source = '''
fn build() {
  return Column([
    ScrollView({ direction: "horizontal" }, 
      Row({ spacing: 16 }, [
        QuickAction("cart", "Achats"),
        QuickAction("favorite", "Épargne"),
        QuickAction("star", "Objectifs")
      ])
    ),
    Text("Done")
  ])
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();

      if (parser.errors().isNotEmpty) {
        print('FAILED: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });

    test('should parse exact output_raw.ks with UTF-8 characters', () {
      // EXACT reproduction with UTF-8 É in Épargne
      final source = '''
fn build() {
  return Scaffold({ backgroundColor: "#fefcf3" }, 
    Box({ color: "#fefcf3", height: "infinity", width: "infinity" }, 
      ScrollView({ padding: 16, direction: "vertical" }, 
        Column({ spacing: 16 }, [
          Row({ mainAxisAlignment: "spaceBetween", crossAxisAlignment: "center" }, [
            Column({ crossAxisAlignment: "start", spacing: 4 }, [
              Text("Bonjour, Issa", { fontSize: 14, color: "grey" }),
              Text("Tableau de bord", { fontSize: 24, fontWeight: "bold", color: "black" })
            ]),
            Row({ spacing: 12 }, [
              IconButton("refresh", { size: 24, color: "black", onTap: "onRefresh" }),
              Box({ width: 48, height: 48, borderRadius: 24, color: "black" }, 
                Icon("person", { size: 24, color: "white" })
              )
            ])
          ]),
          Box({ width: "infinity", padding: 24, borderRadius: 16, color: "black" }, 
            Column({ spacing: 8 }, [
              Text("Solde total", { fontSize: 14, color: "white" }),
              Obx({ builder: "balanceBuilder" })
            ])
          ),
          ScrollView({ direction: "horizontal", padding: 0.1 }, 
            Row({ spacing: 16 }, [
              QuickAction("cart", "Achats", colors.purple, "onShop"),
              QuickAction("home", "Maison", colors.warning, "onHome"),
              QuickAction("favorite", "Épargne", colors.pink, "onSave"),
              QuickAction("star", "Objectifs", colors.success, "onGoals"),
              QuickAction("swap_horiz", "Transfert", colors.primary, "onTransfer")
            ])
          ),
          Text("Transactions récentes", { fontSize: 18, fontWeight: "bold", color: "black" }),
          Obx({ builder: "transactionsBuilder" })
        ])
      )
    )
  )
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();

      if (parser.errors().isNotEmpty) {
        print('FAILED: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });
  });
}
