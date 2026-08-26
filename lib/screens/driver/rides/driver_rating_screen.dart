import 'package:flutter/material.dart';
import '../../../config/colors.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';

class DriverRatingScreen extends StatefulWidget {
  final int rideId;
  final String passengerName;
  const DriverRatingScreen({super.key, required this.rideId, required this.passengerName});
  @override State<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends State<DriverRatingScreen> {
  int selectedRating=0; bool sending=false;
  final commentController=TextEditingController();
  @override void dispose(){commentController.dispose();super.dispose();}
  Future<void> _send() async {
    if(selectedRating==0){_message('Escolha uma nota.');return;}
    final userId=int.tryParse(await AuthService.getUserId()??'');
    if(userId==null||userId<=0){_message('Usuário não identificado.');return;}
    setState(()=>sending=true);
    final result=await ApiService.rateClient(rideId: widget.rideId,userId:userId,rating:selectedRating,comment:commentController.text);
    if(!mounted)return;
    if(result['success']!=true){setState(()=>sending=false);_message(result['message']?.toString()??'Não foi possível avaliar o cliente.');return;}
    Navigator.pop(context,true);
  }
  void _message(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Avaliar cliente')),
    body: ListView(padding: const EdgeInsets.all(24),children:[
      const SizedBox(height:20),
      const Icon(Icons.person_rounded,size:64,color:AppColors.primary),
      const SizedBox(height:14),
      Text(widget.passengerName,textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
      const SizedBox(height:8),
      const Text('Como foi a experiência com o passageiro?',textAlign:TextAlign.center,style:TextStyle(color:Colors.grey)),
      const SizedBox(height:28),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(5,(i)=>IconButton(iconSize:44,onPressed: sending?null:()=>setState(()=>selectedRating=i+1),icon:Icon(i<selectedRating?Icons.star:Icons.star_border,color:i<selectedRating?Colors.amber:Colors.grey)))),
      const SizedBox(height:16),
      TextField(controller:commentController,maxLines:4,decoration:const InputDecoration(labelText:'Comentário (opcional)',border:OutlineInputBorder())),
      const SizedBox(height:22),
      SizedBox(height:52,child:ElevatedButton(onPressed:sending?null:_send,child:sending?const CircularProgressIndicator(color:Colors.white):const Text('Enviar avaliação'))),
      const SizedBox(height:10),
      TextButton(onPressed:sending?null:()=>Navigator.pop(context,false),child:const Text('Avaliar depois')),
    ]),
  );
}
