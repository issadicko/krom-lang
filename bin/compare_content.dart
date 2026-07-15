import 'dart:io';
import 'package:krom_script/krom_script.dart';

void main() async {
  // This is the EXACT content from the file, copied character-by-character
  final fileContent =
      await File('../krom_bundler/example/output_raw.ks').readAsString();
  final lines = fileContent.split('\n');
  final buildFn = lines.sublist(86, 131).join('\n');

  // This is the same content as a string literal (should pass)
  final literalBuildFn = '''
fn build() {
  return Scaffold({ backgroundColor: "#fefcf3" }, 
    Box({ color: "#fefcf3", height: "infinity", width: "infinity" }, 
      ScrollView({ padding: 16, direction: "vertical" }, 
        Column({ spacing: 16 }, [
          // Header
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
          
          // Balance Card
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
          
          // Transactions
          Text("Transactions recentes", { fontSize: 18, fontWeight: "bold", color: "black" }),
          Obx({ builder: "transactionsBuilder" })
        ])
      )
    )
  )
}
''';

  print('=== FROM FILE ===');
  var parser = Parser(Lexer(buildFn));
  parser.parseProgram();
  print(parser.errors().isEmpty
      ? 'SUCCESS'
      : 'FAILED: ${parser.errors().length} errors');

  print('\n=== FROM LITERAL ===');
  parser = Parser(Lexer(literalBuildFn));
  parser.parseProgram();
  print(parser.errors().isEmpty
      ? 'SUCCESS'
      : 'FAILED: ${parser.errors().length} errors');

  // Find differences
  print('\n=== DIFFERENCES ===');
  print('File length: ${buildFn.length} chars');
  print('Literal length: ${literalBuildFn.length} chars');

  // Compare line by line
  final fileLines = buildFn.split('\n');
  final literalLines = literalBuildFn.split('\n');

  print('File lines: ${fileLines.length}');
  print('Literal lines: ${literalLines.length}');

  for (int i = 0; i < fileLines.length && i < literalLines.length; i++) {
    if (fileLines[i] != literalLines[i]) {
      print('\nLine ${i + 1} DIFFERS:');
      print('  FILE:    |${fileLines[i]}|');
      print('  LITERAL: |${literalLines[i]}|');
      print('  File bytes: ${fileLines[i].codeUnits}');
      print('  Literal bytes: ${literalLines[i].codeUnits}');
    }
  }
}
