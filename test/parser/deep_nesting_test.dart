import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('Parser - Deep nesting reproduction', () {
    test('should parse exact structure from output_raw.ks', () {
      // EXACT reproduction of the structure from output_raw.ks
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
              QuickAction("favorite", "Epargne", colors.pink, "onSave"),
              QuickAction("star", "Objectifs", colors.success, "onGoals"),
              QuickAction("swap_horiz", "Transfert", colors.primary, "onTransfer")
            ])
          ),
          Text("Transactions recentes", { fontSize: 18, fontWeight: "bold", color: "black" }),
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

    test('should parse simpler nested version', () {
      final source = '''
fn build() {
  return Scaffold({ a: 1 }, 
    Box({ b: 2 }, 
      ScrollView({ c: 3 }, 
        Column({ d: 4 }, [
          Row({ e: 5 }, [Text("a"), Text("b")]),
          Box({ f: 6 }, Column({ g: 7 }, [Text("c")])),
          ScrollView({ h: 8 }, Row({ i: 9 }, [Item("x"), Item("y")])),
          Text("z")
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
