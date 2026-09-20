import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../l10n/zh_CN.dart";
import "../services/reading_service.dart";
import "../services/study_session_service.dart";
import "../widgets/reading_result_view.dart";

class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key});
  @override State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final _svc = ReadingService();
  final _ctrl = TextEditingController();
  final _study = StudySessionService.instance;
  ReadingResult? _result;
  bool _loading = false;
  String? _error;
  @override void initState() { super.initState(); _study.start("reading"); }

  Future<void> _analyze() async {
    final txt = _ctrl.text.trim();
    if (txt.length < 10) { setState(() => _error = AppStrings.articleTooShort); return; }
    setState(() { _loading = true; _error = null; _result = null; });
    try { _result = await _svc.analyze(txt); } catch (e) { debugPrint("ReadingPage analyze error: $e"); _error = AppStrings.analysisFailed; }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override void dispose() { _study.end("reading"); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.readingAssistant), actions: [
        IconButton(icon: const Icon(Icons.history), tooltip: AppStrings.readingHistory, onPressed: () => ctx.push("/reading/history")),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _ctrl, maxLines: 8, minLines: 5, decoration: InputDecoration(hintText: AppStrings.pasteArticle, labelText: AppStrings.article, alignLabelWithHint: true)),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: _loading?null:_analyze, icon: _loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.auto_awesome,size:18), label: Text(_loading?AppStrings.analyzing:AppStrings.analyzeAI)),
        if (_error!=null) Padding(padding:const EdgeInsets.only(top:12),child:Text(_error!,style:TextStyle(color:Theme.of(ctx).colorScheme.error))),
        if (_result!=null)...[const SizedBox(height:20),ReadingResultView(result:_result!)],
      ]),
    );
  }


}
