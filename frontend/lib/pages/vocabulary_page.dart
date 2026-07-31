import "package:flutter/material.dart";
class VocabularyPage extends StatelessWidget {
  const VocabularyPage({super.key});
  @override Widget build(BuildContext ctx) => Scaffold(appBar: AppBar(title: const Text("Vocabulary")), body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu_book, size: 64, color: Colors.grey), SizedBox(height: 16), Text("Word Learning", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), SizedBox(height: 8), Text("Build your vocabulary with spaced repetition.")])));
}
