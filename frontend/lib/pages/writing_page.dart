import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../l10n/zh_CN.dart";
import "../services/writing_service.dart";
import "../services/study_session_service.dart";
import "../widgets/writing_result_view.dart";

class WritingPage extends StatefulWidget {
  const WritingPage({super.key});
  @override State<WritingPage> createState() => _WritingPageState();
}

class _WritingPageState extends State<WritingPage> {
  final _svc = WritingService();
  final _ctrl = TextEditingController();
  final _study = StudySessionService.instance;
  WritingResult? _result;
  bool _loading = false;
  String? _error;
  @override void initState() { super.initState(); _study.start("writing"); }

  Future<void> _review() async {
    final txt = _ctrl.text.trim();
    if (txt.length < 10) { setState(() => _error = AppStrings.articleTooShort); return; }
    setState(() { _loading = true; _error = null; _result = null; });
    try { _result = await _svc.review(txt); } catch (e) { debugPrint("WritingPage review error: $e"); _error = AppStrings.reviewFailed; }
    setState(() => _loading = false);
  }

  @override void dispose() { _study.end("writing"); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.essayReview), actions: [
        IconButton(icon: const Icon(Icons.history), tooltip: AppStrings.writingHistory, onPressed: () => ctx.push("/writing/history")),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _ctrl, maxLines: 10, minLines: 6, decoration: InputDecoration(hintText: AppStrings.pasteEssay, labelText: AppStrings.yourEssay, alignLabelWithHint: true)),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: _loading?null:_review, icon: _loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.rate_review,size:18), label: Text(_loading?AppStrings.reviewing:AppStrings.aiReview)),
        if (_error!=null) Padding(padding:const EdgeInsets.only(top:12),child:Text(_error!,style:TextStyle(color:Theme.of(ctx).colorScheme.error))),
        if (_result!=null)...[const SizedBox(height:20),WritingResultView(result:_result!)],
      ]),
    );
  }

}
