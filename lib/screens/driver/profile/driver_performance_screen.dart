import 'package:flutter/material.dart';

import '../../../config/colors.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';

class DriverPerformanceScreen extends StatefulWidget {
  const DriverPerformanceScreen({super.key});
  @override
  State<DriverPerformanceScreen> createState() => _DriverPerformanceScreenState();
}

class _DriverPerformanceScreenState extends State<DriverPerformanceScreen> {
  Map<String,dynamic> data = {};
  bool loading = true;
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    final id=int.tryParse(await AuthService.getUserId() ?? '');
    if(id==null)return;
    final r=await ApiService.getDriverRewards(id);
    if(!mounted)return;
    setState((){data=r;loading=false;});
  }
  @override Widget build(BuildContext context){
    final score=int.tryParse('${data['score']??0}')??0;
    final level=data['level']?.toString()??'Bronze';
    final weekly=int.tryParse('${data['weekly_points']??0}')??0;
    final rank=int.tryParse('${data['weekly_rank']??0}')??0;
    final top10=data['top10'] is List ? List<dynamic>.from(data['top10']) : <dynamic>[];
    return Scaffold(backgroundColor:AppColors.background,appBar:AppBar(title:const Text('Meu desempenho'),backgroundColor:AppColors.primary,foregroundColor:Colors.white),body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(18),children:[Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[const Text('🏍️ Driver Score',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:10),Text(level,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),Text('$score pontos totais',style:const TextStyle(color:Colors.grey)),const SizedBox(height:14),Text('🏆 Ranking semanal: ${rank>0?'#$rank':'sem posição'} • $weekly pts',style:const TextStyle(fontWeight:FontWeight.w600))]))),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('🏆 Top 10 da semana',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),const SizedBox(height:8),...top10.asMap().entries.map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(radius:15,child:Text('${e.key+1}')),title:Text(e.value['name']?.toString()??'Motorista'),trailing:Text('${e.value['weekly_points']??0} pts')))]))),const SizedBox(height:12),const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Os níveis e o ranking são apenas reconhecimento de desempenho. Não dão prioridade de corridas, desconto, aumento de ganhos ou qualquer outra vantagem operacional.',style:TextStyle(height:1.45))))])));
  }
}
