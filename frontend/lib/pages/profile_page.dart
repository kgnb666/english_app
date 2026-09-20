import "package:flutter/material.dart";
import "package:dio/dio.dart";
import "package:provider/provider.dart";
import "package:go_router/go_router.dart";
import "../l10n/server_messages.dart";
import "../l10n/zh_CN.dart";
import "../services/auth_provider.dart";
import "../services/api_service.dart";
import "../services/stats_service.dart";
import "../services/theme_provider.dart";
import "../config/theme.dart";

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _svc = StatsService(), _api = ApiService();
  DashboardModel? _dash;
  bool _loading = true;
  String? _level;
  String? _error;
  final _levels = ["beginner", "elementary", "intermediate", "upper_intermediate", "advanced"];

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    var failed = false;
    try { _dash = await _svc.getDashboard(); } catch (e) { debugPrint("ProfilePage dashboard error: $e"); failed = true; }
    try { final r = await _api.dio.get("/auth/me"); _level = r.data["english_level"]; } catch (e) { debugPrint("ProfilePage me error: $e"); failed = true; }
    if (failed) _error = AppStrings.loadFailed;
    setState(()=>_loading=false);
  }

  Future<void> _updateLevel(String level) async {
    try { await _api.dio.patch("/auth/me", data: {"english_level": level}); if (mounted) setState(()=>_level=level); }
    catch (e) { debugPrint("ProfilePage update level error: $e"); }
  }
  Future<void> _updateGoals(int min, int words) async {
    try { await _api.dio.patch("/auth/me", data: {"daily_goal_minutes": min, "daily_goal_words": words}); _load(); }
    catch (e) { debugPrint("ProfilePage update goals error: $e"); }
  }

  void _showLevelPicker() {
    showModalBottomSheet(context:context, builder:(ctx)=>ListView(shrinkWrap:true,children:[
      Padding(padding:const EdgeInsets.all(16),child:Text(AppStrings.selectLevel,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600))),
      ..._levels.map((l)=>ListTile(title:Text(AppStrings.levelLabel(l)),trailing:_level==l?const Icon(Icons.check,color:AppTheme.primaryColor):null,onTap:(){_updateLevel(l);Navigator.pop(ctx);})),
    ]));
  }

  void _showGoalDialog() {
    final minCtrl=TextEditingController(text:"${_dash?.today["study_minutes"]??30}"),wordCtrl=TextEditingController(text:"20");
    showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(AppStrings.dailyGoals),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:minCtrl,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:AppStrings.minutesPerDay)),
      const SizedBox(height:12),
      TextField(controller:wordCtrl,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:AppStrings.wordsPerDay)),
    ]),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(AppStrings.cancel)),
      TextButton(onPressed:(){_updateGoals(int.tryParse(minCtrl.text)??30,int.tryParse(wordCtrl.text)??20);Navigator.pop(ctx);},child:Text(AppStrings.save)),
    ]));
  }

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(AppStrings.changePassword),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: AppStrings.oldPassword, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppStrings.newPassword,
                helperText: AppStrings.passwordHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: AppStrings.confirmPassword, border: const OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
            TextButton(
              onPressed: () => _submitChangePassword(ctx, setDialogState, oldCtrl, newCtrl, confirmCtrl),
              child: Text(AppStrings.save),
            ),
          ],
        ),
      ),
    ).then((_) {
      oldCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    });
  }

  Future<void> _submitChangePassword(
    BuildContext dialogCtx,
    StateSetter setDialogState,
    TextEditingController oldCtrl,
    TextEditingController newCtrl,
    TextEditingController confirmCtrl,
  ) async {
    final oldPwd = oldCtrl.text;
    final newPwd = newCtrl.text.trim();
    if (oldPwd.isEmpty || newPwd.isEmpty) {
      _toast(AppStrings.passwordRequired);
      return;
    }
    if (newPwd.length < 6) {
      _toast(AppStrings.passwordTooShort);
      return;
    }
    if (newPwd != confirmCtrl.text) {
      _toast(AppStrings.passwordsMismatch);
      return;
    }
    setDialogState(() {});
    try {
      await _api.dio.post("/auth/change-password", data: {"old_password": oldPwd, "new_password": newPwd});
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      _toast(AppStrings.changePasswordSuccess, ok: true);
    } on DioException catch (e) {
      debugPrint("change password dio error: ${e.response?.data}");
      final detail = e.response?.data is Map ? e.response!.data["detail"] : null;
      _toast(ServerMessages.localize(detail, fallback: AppStrings.changePasswordFailed));
    } catch (e) {
      debugPrint("change password error: $e");
      _toast(AppStrings.changePasswordFailed);
    }
  }

  void _toast(String message, {bool ok = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: ok ? Colors.green : null));
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.logout),
        content: Text(AppStrings.confirmLogout),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.confirm, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) context.go("/login");
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final auth=ctx.watch<AuthProvider>(),theme=ctx.watch<ThemeProvider>(),t=Theme.of(ctx),d=_dash;
    return Scaffold(appBar:AppBar(title:Text(AppStrings.profile)),
      body:RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
        if(_error!=null)...[
          Material(
            color: t.colorScheme.errorContainer.withAlpha(120),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(Icons.cloud_off_outlined, size: 18, color: t.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(fontSize: 13, color: t.colorScheme.error))),
                TextButton(onPressed: _load, child: Text(AppStrings.retry)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(child:Padding(padding:const EdgeInsets.all(20),child:Row(children:[
          CircleAvatar(radius:30,backgroundColor:AppTheme.primaryColor,child:Text((auth.username??"U")[0].toUpperCase(),style:const TextStyle(fontSize:24,color:Colors.white))),
          const SizedBox(width:16),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(auth.username??"User",style:t.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w600)),
            const SizedBox(height:2),
            Text(AppStrings.levelLabel(_level??"beginner"),style:TextStyle(color:AppTheme.primaryColor,fontSize:13)),
          ])),
        ]))),
        const SizedBox(height:12),
        if(!_loading&&d!=null)...[_statsCard(d,t),const SizedBox(height:12)],
        Card(child:Column(children:[
          SwitchListTile(secondary:Icon(theme.isDark?Icons.dark_mode:Icons.light_mode,color:AppTheme.primaryColor),title:Text(AppStrings.darkMode),value:theme.isDark,onChanged:(_)=>theme.toggle()),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.school,color:AppTheme.primaryColor),title:Text(AppStrings.englishLevel),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(AppStrings.levelLabel(_level??"beginner"),style:TextStyle(fontSize:13,color:Colors.grey.shade600)),const Icon(Icons.chevron_right)]),onTap:_showLevelPicker),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.flag,color:AppTheme.primaryColor),title:Text(AppStrings.dailyGoals),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text("${d?.today["study_minutes"]??0}/30 min",style:TextStyle(fontSize:13,color:Colors.grey.shade600)),const Icon(Icons.chevron_right)]),onTap:_showGoalDialog),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.notifications_active,color:AppTheme.primaryColor),title:Text(AppStrings.reminderSettings),trailing:const Icon(Icons.chevron_right),onTap:()=>context.push("/reminder")),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.event_note,color:AppTheme.primaryColor),title:Text(AppStrings.planTitle),trailing:const Icon(Icons.chevron_right),onTap:()=>context.push("/plan")),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.face_retouching_natural,color:AppTheme.primaryColor),title:Text(AppStrings.learningProfile),trailing:const Icon(Icons.chevron_right),onTap:()=>context.push("/learning-profile")),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.backup_outlined,color:AppTheme.primaryColor),title:Text(AppStrings.dataBackup),trailing:const Icon(Icons.chevron_right),onTap:()=>context.push("/backup")),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.dns_outlined,color:AppTheme.primaryColor),title:Text(AppStrings.serverSettings),trailing:const Icon(Icons.chevron_right),onTap:()=>context.push("/server-settings")),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.lock_outline,color:AppTheme.primaryColor),title:Text(AppStrings.changePassword),trailing:const Icon(Icons.chevron_right),onTap:_showChangePasswordDialog),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.insights_outlined,color:AppTheme.primaryColor),title:Text(AppStrings.statsTitle),trailing:const Icon(Icons.chevron_right),onTap:()=>context.push("/stats")),
        ])),
        const SizedBox(height:24),
        OutlinedButton(onPressed:_confirmLogout,style:OutlinedButton.styleFrom(foregroundColor:t.colorScheme.error,minimumSize:const Size(double.infinity,48),side:BorderSide(color:t.colorScheme.error)),child:Text(AppStrings.logout)),
      ])));
  }

  Widget _statsCard(DashboardModel d,ThemeData t){final total=d.total;return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(AppStrings.learningSummary,style:t.textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w600)),const SizedBox(height:12),Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_si(String.fromCharCode(0x1F525),"${d.streakDays}",AppStrings.dayStreak),_si(String.fromCharCode(0x23F0),"${total["study_minutes"]??0}m",AppStrings.totalTime),_si(String.fromCharCode(0x1F4AC),"${total["chat_messages"]??0}",AppStrings.chatsLabel),_si(String.fromCharCode(0x1F4DA),"${total["words_learned"]??0}",AppStrings.wordsLabel)])])));}
  Widget _si(String e,String v,String l)=>Column(children:[Text(e,style:const TextStyle(fontSize:22)),const SizedBox(height:2),Text(v,style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold)),Text(l,style:TextStyle(fontSize:11,color:Colors.grey.shade600))]);
}
