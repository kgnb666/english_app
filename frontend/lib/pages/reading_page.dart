import "package:flutter/material.dart";
class ReadingPage extends StatelessWidget {
  const ReadingPage({super.key});
  @override Widget build(BuildContext ctx) => Scaffold(appBar: AppBar(title: const Text("Reading")), body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.article_outlined, size: 64, color: Colors.grey), SizedBox(height: 16), Text("AI Reading Assistant", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), SizedBox(height: 8), Text("Paste an English article for AI analysis.")])));
}
