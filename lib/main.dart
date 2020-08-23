import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';
import 'dart:collection';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'key.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart';
import 'package:photo_view/photo_view.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/gestures.dart';
import 'package:share/share.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:collection/collection.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

bool light;

PersistentData settingsData = PersistentData(name:"settings",external:false);

PersistentData userIdData = PersistentData(name:"themeinfo",external:false);

dynamic realUserId = Platform.isAndroid?PersistentData(name:"userId",external:true):FlutterSecureStorage();

PersistentData createdPollsData = PersistentData(name:"createdinfo",external:false);

PersistentData messages = PersistentData(name:"messages",external:false);

PersistentData policy = PersistentData(name:"privacyPolicy",external:false);

String lastMessage;

dynamic actualUserLevel;

dynamic currentUserLevel;

int numSettings = 3;

String userId;

List<dynamic> settings;

List<dynamic> createdPolls;

Map<String,dynamic> data;

ScrollController s = ScrollController();

bool hasLoaded = false;

Color color = Color.fromRGBO(52,52,52,1.0);

Color textColor = Color.fromRGBO(34, 34, 34,1.0);

ConnectivityResult current;

Connectivity connection = Connectivity();

bool agreesToPolicy = false;

int permsCount = 0;

String openedPoll;

Color indicatorColor;

List<String> unLoadedPolls = List<String>();

bool isCorrectVersion;

String version = "2.0.4";

bool displayedVersionMessage = false;

bool displayedBannedMessage = false;

ValueNotifier<String> removedNotifier = ValueNotifier<String>(null);

Map<int,List> tutorialMessages = {
  1:[false,"This is the create page. You can enter in all of your poll options and click submit to create a poll. Then, the app will generare a 4 character code which you can use to open or share the poll. If you make the poll publicly searchable it will appear on the Browse page."],
  2:[false,"This is the vote page. You can use the four character codes found under the question of every poll the open them here."],
  4:[false,"This is the settings page. You can customize your app here. In dark mode, the app switches to a darker theme which prevents eye strain. In safe mode, the app attempts to filter polls with inappropriate content out of the browse page."]
};

void main() async{
  if(Platform.isAndroid){
    int count = 0;
    bool hasPerms = (await PermissionHandler().checkPermissionStatus(PermissionGroup.storage))==PermissionStatus.granted;
    while(!hasPerms){
      hasPerms = (await PermissionHandler().requestPermissions([PermissionGroup.storage]))[PermissionGroup.storage]==PermissionStatus.granted;
      if(++count==10){
        runApp(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>Container(child:Center(child:Column(mainAxisAlignment: MainAxisAlignment.center,children:[Padding(padding: EdgeInsets.only(left:MediaQuery.of(context).size.width*.05,right:MediaQuery.of(context).size.width*.05),child:FittedBox(fit: BoxFit.scaleDown,child:Text("In order to use PPoll you must enable storage permissions.",style:TextStyle(fontSize:10000.0)))),RichText(text:TextSpan(text:"\nGrant Permissions",style: TextStyle(color:Colors.blue,fontSize:20.0),recognizer: TapGestureRecognizer()..onTap = (){
          PermissionHandler().openAppSettings();
          waitForPerms(int count) async{
            if(!hasPerms&&(await PermissionHandler().checkPermissionStatus(PermissionGroup.storage))==PermissionStatus.granted){
              hasPerms = true;
              main();
              return;
            }
            if(count==permsCount){
              Timer(Duration(seconds:1),(){
                waitForPerms(count);
              });
            }
          }
          waitForPerms(++permsCount);
        }))])))))));
        return;
      }
    }
  }
  current = await connection.checkConnectivity();
  agreesToPolicy = await policy.readData();
  if(agreesToPolicy==null){
    policy.writeData(false);
    agreesToPolicy=false;
  }
  settings = await settingsData.readData();
  if(settings==null){
    settings = List<dynamic>();
  }
  if(settings.length>numSettings){
    settings = settings.sublist(0,numSettings);
    await settingsData.writeData(settings);
  }else if(settings.length<numSettings){
    settings.addAll(List<dynamic>(numSettings-settings.length).map((n)=>false));
    if(settings[1] is bool){
      settings[1] = "After Vote";
    }
    await settingsData.writeData(settings);
  }
  //indicatorColor = !settings[0]?Color.fromRGBO(33,150,243,1.0):Color.fromRGBO(100,255,218,1.0);
  indicatorColor = Color.fromRGBO(33,150,243,1.0);
  textColor = !settings[0]?Color.fromRGBO(34, 34, 34,1.0):Colors.white;
  color = !settings[0]?Color.fromRGBO(52,52,52,1.0):Color.fromRGBO(22,22,22,1.0);
  if(Platform.isIOS){
    userId = await realUserId.read(key: "PPollUserID");
    if(userId==null){
      for(int i in tutorialMessages.keys){
        tutorialMessages[i][0] = true;
      }
      userId = await userIdData.readData();
      if(userId!=null){
        await realUserId.write(key: "PPollUserID", value: userId);
      }
    }
  }else{
    userId = await realUserId.readData();
    if(userId==null){
      for(int i in tutorialMessages.keys){
        tutorialMessages[i][0] = true;
      }
      userId = await userIdData.readData();
      if(userId!=null){
        await realUserId.writeData(userId);
      }
    }
  }
  if(userId==null){
    doWhenHasConnection(() async{
      Map<String,dynamic> usersMap = json.decode((await http.get(Uri.parse(database+"/users.json?auth="+secretKey))).body);
      userId = "";
      do{
        userId = "";
        Random r = Random();
        List<String> nums = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
        for(int i = 0;i<16;i++){
          userId+=(r.nextInt(2)==0?nums[r.nextInt(36)]:nums[r.nextInt(36)].toLowerCase());
        }
      }while(usersMap["userId"]!=null);
      await http.put(Uri.encodeFull(database+"/users/$userId.json?auth="+secretKey),body:"[0]");
      if(Platform.isIOS){
        await realUserId.write(key: "PPollUserID", value: userId);
      }else{
        await realUserId.writeData(userId);
      }
      await userIdData.writeData(userId);
    });
    createdPolls=List<dynamic>();
  }else{
    doWhenHasConnection(() async{
      createdPolls = json.decode((await http.get(Uri.encodeFull(database+"/users/$userId/1.json?auth="+secretKey))).body);
      if(createdPolls==null){
        createdPolls = await createdPollsData.readData();
        if(createdPolls!=null){
          await http.put(Uri.encodeFull(database+"/users/$userId/1.json?auth="+secretKey),body:json.encode(createdPolls));
        }else{
          createdPolls = List<dynamic>();
        }
      }
    });
  }
  doWhenHasConnection(() async{
    String minVersion = json.decode((await http.get(Uri.encodeFull("$database/${Platform.isIOS?"iosVersion":"androidVersion"}.json?auth=$secretKey"))).body);
    isCorrectVersion = int.parse(minVersion.replaceAll(".",""))<=int.parse(version.replaceAll(".",""));
  });
  lastMessage = (await messages.readData());
  runApp(App());
}

doWhenHasConnection(Function function) async{
  try{
    final result = await InternetAddress.lookup("google.com");
    if(result.isNotEmpty && result[0].rawAddress.isNotEmpty){
      function();
    }
  }on SocketException catch(_){
    print("Bad connection, retrying...");
    Timer(Duration(seconds:1),await doWhenHasConnection(function));
  }
}

bool start = true;

bool hasGotLevel = false;

class App extends StatefulWidget{
  @override
  AppState createState() => AppState();
}

class AppState extends State<App>{

  HttpClient client = HttpClient();

  void setUp(ConnectivityResult r) async{
    Stopwatch watch = Stopwatch();
    watch.start();
    waitForConnection() async{
      if(r!=current){
        return;
      }
      if(userId==null||createdPolls==null||isCorrectVersion==null){
        Timer(Duration(seconds:1),waitForConnection);
        return;
      }
      try{
        final result = await InternetAddress.lookup("google.com");
        if(result.isNotEmpty&&result[0].rawAddress.isNotEmpty){
          data = json.decode(utf8.decode((await http.get(Uri.encodeFull(database+"/data.json?auth="+secretKey))).bodyBytes));
          for(int i = 0; i<data.keys.length;i++){
            String key = data.keys.toList()[i];
            if(data[key]["a"]==null){
              data.remove(key);
              i--;
              http.delete(Uri.encodeFull(database+"/data/"+key+".json?auth="+secretKey));
              continue;
            }
            if(data[key]["i"]!=null){
              for(String s in data[key]["i"].keys){
                if(data[key]["b"][0]==1&&!data[key]["i"][s].contains(-1)){
                  data[key]["i"][s].forEach((i){
                    data[key]["a"][i]++;
                  });
                }else if(data[key]["b"][0]==0){
                  if(data[key]["i"][s]!=-1){
                    data[key]["a"][data[key]["i"][s]]++;
                  }
                }
              }
            }
          }
          client = HttpClient();
          client.openUrl("GET", Uri.parse(database+"/data.json?auth="+secretKey)).then((req) async{
            req.headers.set("Accept", "text/event-stream");
            req.followRedirects = true;
            req.close().then((response) async{
              if(response.statusCode == 200){
                if(!hasLoaded){
                  setState((){hasLoaded = true;});
                }
                response.listen((bytes){
                  String text;
                  try{
                    text = utf8.decode(bytes);
                  }catch(e){
                    return;
                  }
                  if(text.split(":").length>1&&text.split(":")[1].contains("keep-alive")){
                    print("Keep-alive ${watch.elapsedMilliseconds}");
                    watch.reset();
                    watch.start();
                  }else{
                    dynamic returned;
                    try{
                      returned = json.decode(text.substring(text.indexOf("{"),text.lastIndexOf("}")+1));
                    }catch(e){
                      return;
                    }
                    if(returned["path"]==null){
                      return;
                    }
                    List<dynamic> path = returned["path"].split("/");
                    if(path.length>=3&&data[path[1]]==null&&path[2]=="i"&&returned["data"]!=null){
                      http.delete(Uri.encodeFull(database+"/data/"+path[1]+".json?auth="+secretKey));
                      return;
                    }else if(path.length==2&&(data[path[1]]==null||(data[path[1]]!=null&&data[path[1]]["a"]==null))&&returned["data"]==null){
                      return;
                    }
                    if(returned["data"]!=null){
                      if(((path!=null&&path.length==2)&&(returned["data"]["b"][2]==1||currentUserLevel==1)&&index==0)&&(!settings[2]||(settings[2]&&returned["data"]["p"]==0))){
                        unLoadedPolls.add(path[1]);
                      }
                      if(path!=null&&path.length==2&&returned["data"]!=null&&returned["data"]["u"]==userId){
                        createdPolls.add(path[1]);
                        if(index==3){
                          unLoadedPolls.add(path[1]);
                        }
                      }
                    }
                    dynamic finalPath = path[path.length-1];
                    dynamic temp = data;
                    String code = path!=null&&path.length>1?path[1].toString():null;
                    dynamic before;
                    path.sublist(1,path.length-1).forEach((o){
                      if(path.indexOf(o)==path.length-2){
                        before = temp;
                      }
                      try{
                        int i = int.parse(o);
                        if(temp[i]==null){
                          throw Exception();
                        }
                        temp = temp[i];
                      }catch(e){
                        temp = temp[o];
                      }
                    });
                    if(index==0||index==3||(index==1||index==2&&openedPoll!=null&&openedPoll==code)){
                      setState((){
                        try{
                          int i = int.parse(finalPath);
                          if(returned["data"]==null){
                            temp.remove(i);
                            if(path!=null&&path.length==2){
                              if(index==0||(index==3&&createdPolls.contains(path[1]))){
                                unLoadedPolls.remove(path[1]);
                              }
                              removedNotifier.value = path[1];
                            }
                          }else{
                            if(temp==null){
                              before[path[path.length-2]] = {};
                              temp = before[path[path.length-2]];
                            }
                            temp[i] = returned["data"];
                          }
                        }catch(e){
                          if(returned["data"]==null){
                            temp.remove(finalPath);
                            if(path!=null&&path.length==2){
                              if(index==0||(index==3&&createdPolls.contains(path[1]))){
                                unLoadedPolls.remove(path[1]);
                              }
                              removedNotifier.value = path[1];
                            }
                          }else{
                            if(temp==null){
                              before[path[path.length-2]] = {};
                              temp = before[path[path.length-2]];
                            }
                            if(path.length==4&&path[2]=="i"){
                              if(before["b"][0]==0){
                                if(temp[finalPath]!=null&&temp[finalPath]!=-1){
                                  before["a"][temp[finalPath]]--;
                                }
                                if(returned["data"]!=-1){
                                  before["a"][returned["data"]]++;
                                }
                              }else{
                                List<int> previous;
                                if(temp[finalPath]!=null){
                                  previous = List.from(temp[finalPath]);
                                  previous.removeWhere((i)=>i==-1);
                                }else{
                                  previous = List<int>();
                                }
                                List<int> after = List.from(returned["data"]);
                                after.removeWhere((i)=>i==-1);
                                if(after.length>previous.length){
                                  (after..removeWhere((i)=>previous.contains(i))).forEach((i){
                                    before["a"][i]++;
                                  });
                                }else if(after.length<previous.length){
                                  (previous..removeWhere((i)=>after.contains(i))).forEach((i){
                                    before["a"][i]--;
                                  });
                                }
                              }
                            }
                            temp[finalPath] = returned["data"];
                          }
                        }
                      });
                    }else{
                      try{
                        int i = int.parse(finalPath);
                        if(returned["data"]==null){
                          temp.remove(i);
                        }else{
                          if(temp==null){
                            before[path[path.length-2]] = {};
                            temp = before[path[path.length-2]];
                          }
                          temp[i] = returned["data"];
                        }
                      }catch(e){
                        if(returned["data"]==null){
                          temp.remove(finalPath);
                        }else{
                          if(temp==null){
                            before[path[path.length-2]] = {};
                            temp = before[path[path.length-2]];
                          }
                          if(path.length==4&&path[2]=="i"){
                            if(before["b"][0]==0){
                              if(temp[finalPath]!=null&&temp[finalPath]!=-1){
                                before["a"][temp[finalPath]]--;
                              }
                              if(returned["data"]!=-1){
                                before["a"][returned["data"]]++;
                              }
                            }else{
                              List<int> previous;
                              if(temp[finalPath]!=null){
                                previous = List.from(temp[finalPath]);
                                previous.removeWhere((i)=>i==-1);
                              }else{
                                previous = List<int>();
                              }
                              List<int> after = List.from(returned["data"]);
                              after.removeWhere((i)=>i==-1);
                              if(after.length>previous.length){
                                (after..removeWhere((i)=>previous.contains(i))).forEach((i){
                                  before["a"][i]++;
                                });
                              }else if(after.length<previous.length){
                                (previous..removeWhere((i)=>after.contains(i))).forEach((i){
                                  before["a"][i]--;
                                });
                              }
                            }
                          }
                          temp[finalPath] = returned["data"];
                        }
                      }
                    }
                  }
                }).onDone((){
                  print("Done");
                  if(hasLoaded){
                    setState((){hasLoaded = false;});
                    setUp(current);
                  }
                });
              }
            });
          });
        }
      }on SocketException catch(_){
        print("Bad connection, retrying...");
        Timer(Duration(seconds:1),waitForConnection);
      }
    }
    waitForConnection();
  }

  static int index = 0;

  Image icon;

  @override
  void initState(){
    super.initState();
    /*
    ensureConnection(){
      Timer(Duration(seconds:1),() async{
        ConnectivityResult r = await connection.checkConnectivity();
        if(r!=current){
          print("$current $r");
          current = r;
          setState((){
            hasLoaded = false;
            client.close(force:true);
          });
          if(r!=ConnectivityResult.none){
            setUp(current);
          }
        }
        ensureConnection();
      });
    }
    ensureConnection();
    */
    connection.onConnectivityChanged.listen((r) async{
      if(r!=current){
        current = r;
        setState((){
          hasLoaded = false;
          client.close(force:true);
        });
        if(current!=ConnectivityResult.none){
          setUp(current);
        }
      }
    });
    if(current!=ConnectivityResult.none){
      setUp(current);
    }
    if(!agreesToPolicy){
      iconCompleter = Completer<ui.Image>();
      icon = Image.asset("icon/platypus2.png");
      icon.image.resolve(ImageConfiguration()).addListener(ImageStreamListener((ImageInfo info, bool b){
        if(!iconCompleter.isCompleted){
          iconCompleter.complete(info.image);
        }
      }));
    }
  }

  Completer<ui.Image> iconCompleter;

  @override
  void dispose(){
    super.dispose();
    client.close(force:true);
  }

  @override
  Widget build(BuildContext context){
    return DynamicTheme(
        themedWidgetBuilder: (context, theme){
          return MaterialApp(
              theme: theme,
              debugShowCheckedModeBanner: false,
              home: agreesToPolicy?Scaffold(
                  bottomNavigationBar: BottomNavigationBar(
                      currentIndex: index,
                      type: BottomNavigationBarType.fixed,
                      fixedColor: settings[0]?indicatorColor:Colors.indigoAccent,
                      items: [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.language),
                          title: Text("Browse"),
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.add_circle_outline),
                          title: Text("New"),
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.check_circle),
                          title: Text("Vote"),
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.dehaze),
                          title: Text("Created"),
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.settings),
                          title: Text("Settings"),
                        ),
                      ],
                      onTap:(i){
                        unLoadedPolls = List<String>();
                        if(loadingData){
                          return;
                        }
                        if(index!=i){
                          setState((){index = i;});
                          removedNotifier.value = null;
                        }else if(((index==0&&i==0)||(index==3&&i==3))&&hasLoaded){
                          s.animateTo(0.0,curve: Curves.easeOut, duration: const Duration(milliseconds: 300));
                        }else if(index==1){
                          createController.animateTo(0.0,curve: Curves.easeOut, duration: const Duration(milliseconds: 300));
                        }
                      }
                  ),
                  body: Builder(
                      builder: (context){
                        if(tutorialMessages[index]!=null && tutorialMessages[index][0]){
                          tutorialMessages[index][0] = false;
                          Future.delayed(Duration.zero,()=>showDialog(context:context,builder:(context)=>AlertDialog(actions: [FlatButton(child: Text("OK"),onPressed:(){Navigator.of(context).pop();})],title:Text("Tutorial",style:TextStyle(fontWeight:FontWeight.bold),textAlign: TextAlign.center),content:Text(tutorialMessages[index][1]))));
                        }
                        if(!displayedBannedMessage&&actualUserLevel==null&&!hasGotLevel){
                          hasGotLevel = true;
                          tryToGetId() async{
                            try{
                              final result = await InternetAddress.lookup("google.com");
                              if(result.isNotEmpty && result[0].rawAddress.isNotEmpty){
                                http.get(Uri.encodeFull("$database/users/$userId/0.json?auth=$secretKey")).then((r){
                                  setState((){
                                    actualUserLevel = json.decode(r.body);
                                    currentUserLevel = 0;
                                  });
                                  if(actualUserLevel is String){
                                    Future.delayed(Duration.zero,()=>showDialog(context:context,barrierDismissible: false,builder:(context)=>AlertDialog(title:Text("You have been banned from PPoll",style:TextStyle(fontWeight:FontWeight.bold),textAlign:TextAlign.center),content:Text("Reason: $actualUserLevel",textAlign: TextAlign.start))));
                                    displayedBannedMessage = true;
                                  }
                                });
                              }
                            }on SocketException catch(_){
                              print("Bad connection, retrying...");
                              Timer(Duration(seconds:1),tryToGetId);
                            }
                          }
                          tryToGetId();
                        }
                        if(isCorrectVersion==true&&(actualUserLevel!=null&&!(actualUserLevel is String))&&start&&agreesToPolicy){
                          start = false;
                          http.get(Uri.encodeFull("$database/message.json?auth=$secretKey")).then((r){
                            String s = json.decode(r.body);
                            if(s=="null"){
                              s=null;
                            }
                            if(s!=lastMessage){
                              lastMessage = s;
                              messages.writeData(lastMessage);
                              if(lastMessage!=null){
                                Future.delayed(Duration.zero,()=>showDialog(context:context,builder:(context)=>AlertDialog(actions: [FlatButton(child: Text("OK"),onPressed:(){Navigator.of(context).pop();})],title:Text("Alert",style:TextStyle(fontWeight:FontWeight.bold),textAlign: TextAlign.center),content:Text(lastMessage))));
                              }
                            }
                          });
                        }
                        if(!displayedVersionMessage&&isCorrectVersion==false&&(actualUserLevel!=null&&!(actualUserLevel is String))){
                          Future.delayed(Duration.zero,()=>showDialog(context:context,barrierDismissible: false,builder:(context)=>WillPopScope(onWillPop: ()=>Future<bool>(()=>false),child:AlertDialog(title:Text("Outdated Version",style:TextStyle(fontWeight:FontWeight.bold),textAlign:TextAlign.center),content:Text("Please update to continue",textAlign: TextAlign.start)))));
                          displayedVersionMessage = true;
                        }
                        return MainPage();
                      }
                  )
              ):Builder(builder:(context){
                double heightOrWidth = min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height);
                double ratio = max(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)/568.0;
                bool landscape = MediaQuery.of(context).size.width>MediaQuery.of(context).size.height;
                List<Widget> widgets = [
                  Container(height:landscape?20.0*ratio:0.0),
                  FutureBuilder(
                    future: iconCompleter.future,
                    builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot){
                      if(snapshot.hasData){
                        if(snapshot.hasData){
                          return Image(image:icon.image,width:heightOrWidth*5/8,height:heightOrWidth*5/8);
                        }
                      }else{
                        return Container(
                            width:heightOrWidth*5/8,
                            height:heightOrWidth*5/8,
                            child:Padding(
                                padding:EdgeInsets.all(heightOrWidth*5/16-25),
                                child:CircularProgressIndicator()
                            )
                        );
                      }
                    },
                  ),
                  Container(height:landscape?20.0*ratio:0.0),
                  Text("Hi there!",style:TextStyle(fontSize:25.0*ratio,color:textColor),textAlign: TextAlign.center),
                  Text("Welcome to PPoll.",style: TextStyle(fontSize:25.0*ratio,color:textColor),textAlign: TextAlign.center),
                  Container(height:landscape?20.0*ratio:0.0),
                  Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:Text("PPoll provides a completely anonymous and ad-free experience.",style:TextStyle(fontSize:15.0*ratio,color:textColor.withOpacity(0.9)),textAlign: TextAlign.center)),
                  Container(height:landscape?40.0*ratio:0.0),
                  Column(
                      children:[
                        Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:Center(child:RichText(
                            textAlign:TextAlign.center,
                            text:TextSpan(
                                children:[
                                  TextSpan(
                                    text:"By pressing the \"Get started\" button and using PPoll, you agree to our ",
                                    style: TextStyle(color: textColor,fontSize:8.0*ratio),
                                  ),
                                  TextSpan(
                                    text:"Privacy Policy",
                                    style: TextStyle(color: Colors.blue,fontSize:8.0*ratio),
                                    recognizer: TapGestureRecognizer()..onTap = () async{
                                      if(await canLaunch("https://platypuslabs.llc/privacypolicy")){
                                        await launch("https://platypuslabs.llc/privacypolicy");
                                      }else{
                                        throw "Could not launch $url";
                                      }
                                    },
                                  ),
                                  TextSpan(
                                    text:" and ",
                                    style: TextStyle(color: textColor,fontSize:8.0*ratio),
                                  ),
                                  TextSpan(
                                    text:"Terms of Use",
                                    style: TextStyle(color: Colors.blue,fontSize:8.0*ratio),
                                    recognizer: TapGestureRecognizer()..onTap = () async{
                                      if(await canLaunch("https://platypuslabs.llc/termsandconditions")){
                                        await launch("https://platypuslabs.llc/termsandconditions");
                                      }else{
                                        throw "Could not launch $url";
                                      }
                                    },
                                  ),
                                  TextSpan(
                                      text:".",
                                      style: TextStyle(fontSize:8.0)
                                  ),
                                ]
                            )
                        ))),
                        Container(height:landscape?10.0*ratio:5.0*ratio),
                        Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:Container(width:double.infinity,child:RaisedButton(
                            padding: EdgeInsets.all(13.0),
                            color:Colors.grey,
                            child:Text("Get started",style:TextStyle(fontSize:12.0*ratio)),
                            onPressed:(){
                              setState((){
                                agreesToPolicy=true;
                                policy.writeData(true);
                              });
                            }
                        )))
                      ]
                  ),
                  Container(height:landscape?50.0*ratio:0.0),
                ];
                return Scaffold(appBar:AppBar(automaticallyImplyLeading:false,title:Text("User agreement"),backgroundColor: color),body:Container(color:!settings[0]?Color.fromRGBO(230, 230, 230, 1.0):Color.fromRGBO(51,51,51,1.0),child:Center(child:!landscape?Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,children:widgets):ListView(children:widgets))));
              })
          );
        },
        data: (brightness) => ThemeData(fontFamily: "Roboto",brightness: settings!=null&&settings[0]?Brightness.dark:Brightness.light),
        defaultBrightness: settings!=null&&settings[0]?Brightness.dark:Brightness.light
    );
  }
}

bool firstOne = true;

class MainPage extends StatefulWidget{
  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with WidgetsBindingObserver{

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state == AppLifecycleState.resumed && !firstOne){
      Timer.periodic(Duration(milliseconds:500),(t){
        if(agreesToPolicy&&hasLoaded){
          t.cancel();
          retrieveDynamicLink();
        }
      });
    }
  }

  @override
  void initState(){
    super.initState();
    Timer.periodic(Duration(milliseconds:500),(t){
      if(agreesToPolicy&&hasLoaded){
        t.cancel();
        firstOne = false;
        retrieveDynamicLink();
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }

  int lastOpenedLink = -1;

  Future<void> retrieveDynamicLink() async{
    final PendingDynamicLinkData linkData = await FirebaseDynamicLinks.instance.retrieveDynamicLink();
    if(linkData==null||linkData.hashCode==lastOpenedLink){
      return;
    }
    lastOpenedLink = linkData.hashCode;
    final Uri deepLink = linkData.link;
    //print(deepLink.toString());
    if(deepLink!=null){
      String id = deepLink.path.split("/").last;
      if(data[id]!=null){
        if(data[id]["p"]==1&&settings[2]&&(data[id]["u"]==null||data[id]["u"]!=userId)){
          showDialog(
              context: this.context,
              barrierDismissible: false,
              builder: (context){
                return AlertDialog(
                    title: Text("Alert",style:TextStyle(fontWeight:FontWeight.bold)),
                    content: Text("The poll you are attempting to open is unsafe."),
                    actions: [
                      FlatButton(
                          child: Text("OK"),
                          onPressed: (){
                            Navigator.of(context).pop();
                          }
                      )
                    ]
                );
              }
          );
          return;
        }
        if(openedPoll==id){
          return;
        }else if(openedPoll!=null){
          Navigator.of(this.context).pop();
        }
        openedPoll = id;
        Navigator.push(this.context,PageRouteBuilder(
          pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
            return PollView(id);
          },
          transitionDuration: Duration(milliseconds: 300),
          transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child){
            return FadeTransition(
                opacity: animation,
                child: child
            );
          },
        )).then((r){
          this.context.ancestorStateOfType(TypeMatcher<AppState>()).setState((){
            AppState.index = 2;
          });
        });
      }else{
        showDialog(
            context: this.context,
            barrierDismissible: false,
            builder: (context){
              return AlertDialog(
                  title: Text("Alert",style:TextStyle(fontWeight:FontWeight.bold)),
                  content: Text("The poll you are attempting to open does not exist."),
                  actions: [
                    FlatButton(
                        child: Text("OK"),
                        onPressed: (){
                          Navigator.of(context).pop();
                        }
                    )
                  ]
              );
            }
        );
      }
    }
  }

  @override
  Widget build(BuildContext context){
    return AppState.index==0?Container(
        color: !settings[0]?Color.fromRGBO(230, 230, 230, 1.0):Color.fromRGBO(51,51,51,1.0),
        child: Center(
            child: View(false)
        )
    ):AppState.index==1?CreatePollPage(
    ):AppState.index==2?OpenPollPage(
    ):AppState.index==3?Container(
        color: !settings[0]?Color.fromRGBO(230, 230, 230, 1.0):Color.fromRGBO(51,51,51,1.0),
        child: Center(
            child: View(true)
        )
    ):Scaffold(appBar:AppBar(title:Text("Settings"),backgroundColor: color),body:Container(
        color: !settings[0]?Color.fromRGBO(230, 230, 230, 1.0):Color.fromRGBO(51,51,51,1.0),
        child: Center(
            child: ListView(
                children: [
                  Padding(padding: EdgeInsets.only(top:12.0),child: Column(
                      children: settings.asMap().keys.map((i)=>Padding(padding:EdgeInsets.only(bottom:12.0),child:GestureDetector(onTap:(){
                        if(i==1){
                          return;
                        }
                        bool b = !settings[i];
                        if(i==0){
                          //indicatorColor = !b?Color.fromRGBO(33,150,243,1.0):Color.fromRGBO(100,255,218,1.0);
                          textColor = !b?Color.fromRGBO(34,34, 34,1.0):Color.fromRGBO(238,238,238,1.0);
                          color = !b?Color.fromRGBO(52,52,52,1.0):Color.fromRGBO(22,22,22,1.0);
                        }
                        context.ancestorStateOfType(TypeMatcher<AppState>()).setState((){settings[i]=b;});
                        settingsData.writeData(settings);
                      },child:Container(color:settings[0]?Colors.black:Color.fromRGBO(253,253,253,1.0),child:ListTile(
                          leading: Icon(i==0?Icons.brightness_2:i==1?Icons.more_vert:i==2?Icons.visibility:Icons.settings),
                          title: Text(i==0?"Dark mode":i==1?"Expand large polls":i==2?"Safe mode":"Placeholder"),
                          trailing: i!=1?Switch(value:settings[i],activeColor:indicatorColor,onChanged:(b){
                            if(i==0){
                              textColor = !b?Color.fromRGBO(34,34, 34,1.0):Color.fromRGBO(238,238,238,1.0);
                              color = !b?Color.fromRGBO(52,52,52,1.0):Color.fromRGBO(22,22,22,1.0);
                            }
                            context.ancestorStateOfType(TypeMatcher<AppState>()).setState((){settings[i]=b;});
                            settingsData.writeData(settings);
                          }):DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                  items: ["Always","After Vote","Never"].map((key)=>DropdownMenuItem<String>(value: key, child: Text("$key"))).toList(),
                                  onChanged: (s){
                                    context.ancestorStateOfType(TypeMatcher<AppState>()).setState((){settings[1] = s;});
                                    settingsData.writeData(settings);
                                  },
                                  value: settings[1]
                              )
                          )
                      ))))).toList()
                  )),
                  actualUserLevel==1?GestureDetector(onTap:(){
                    context.ancestorStateOfType(TypeMatcher<AppState>()).setState((){currentUserLevel = currentUserLevel==0?1:0;});
                  },child:Container(color:settings[0]?Colors.black:Color.fromRGBO(253,253,253,1.0),child:ListTile(
                      leading: Icon(Icons.stars),
                      title: Text("Admin"),
                      trailing: Switch(value: currentUserLevel==1,activeColor:indicatorColor,onChanged: (b){
                        context.ancestorStateOfType(TypeMatcher<AppState>()).setState((){currentUserLevel = b?1:0;});
                      })
                  ))):Container()
                ]
            )
        )
    ));
  }
}

Timer shouldSearchTimer;

class View extends StatefulWidget{
  final bool onlyCreated;
  View(this.onlyCreated):super(key:ValueKey<bool>(onlyCreated));
  @override
  ViewState createState() => ViewState();
}

class ViewState extends State<View>{

  String sorting;

  String search = "";

  bool inSearch = false;

  bool hasSearched = false;

  FocusNode f = FocusNode();

  TextEditingController c = TextEditingController();

  Map<String,dynamic> sortedMap;

  bool loadingNewPolls = false;

  bool lastHasLoaded = hasLoaded;

  VoidCallback onRemoved;

  @override
  void initState(){
    super.initState();
    sorting = widget.onlyCreated?"newest":"trending";
    onRemoved = (){
      if(removedNotifier.value!=null&&data!=null&&sortedMap.keys.contains(removedNotifier.value)){
        setState((){
          sortedMap.remove(removedNotifier.value);
        });
      }
    };
    c.addListener((){
      if(shouldSearchTimer!=null){
        shouldSearchTimer.cancel();
      }
      shouldSearchTimer = Timer(Duration(milliseconds:500),(){
        s.jumpTo(0.0);
        setState((){});
        sortMap();
      });
    });
    removedNotifier.addListener(onRemoved);
  }

  @override
  void dispose(){
    super.dispose();
    removedNotifier.removeListener(onRemoved);
  }

  void sortMap(){
    Map<String,dynamic> tempMap = Map<String,dynamic>()..addAll(data)..removeWhere((key,value){
      return ((widget.onlyCreated&&!createdPolls.contains(key))||(!(key.toUpperCase().contains(search.toUpperCase())||((value as Map<String,dynamic>)["q"] as String).toUpperCase().contains(search.toUpperCase()))||((!widget.onlyCreated&&currentUserLevel!=1)&&((((value as Map<String,dynamic>)["b"])[2]==0)||((value as Map<String,dynamic>)["b"])[0]==1||((value as Map<String,dynamic>)["b"])[1]==1))))||(settings[2]&&data[key]["p"]!=null&&data[key]["p"]==1&&!widget.onlyCreated);
    });
    sortedMap = SplayTreeMap.from(tempMap,(o1,o2){
      int voters1 = tempMap[o1]["a"].reduce((n1,n2)=>n1+n2);
      int voters2 = tempMap[o2]["a"].reduce((n1,n2)=>n1+n2);
      if(!widget.onlyCreated){
        if(sorting=="trending"){
          double currentTime = (DateTime.now().millisecondsSinceEpoch/1000.0);
          double timeChange1 = (currentTime-(tempMap[o1]["t"]!=null?tempMap[o1]["t"]:currentTime/2.0));
          double timeChange2 = (currentTime-(tempMap[o2]["t"]!=null?tempMap[o2]["t"]:currentTime/2.0));
          double trendingIndex1 = pow((voters1+1),1.5)/(pow(timeChange1!=0?timeChange1:.0001,2));
          double trendingIndex2 = pow((voters2+1),1.5)/(pow(timeChange2!=0?timeChange2:.0001,2));
          if(trendingIndex1!=trendingIndex2){
            return trendingIndex2>trendingIndex1?1:-1;
          }else if(tempMap[o1]["q"].compareTo(tempMap[o2]["q"])!=0){
            return tempMap[o1]["q"].compareTo(tempMap[o2]["q"]);
          }
          return o1.compareTo(o2);
        }
        if((sorting=="newest"||sorting=="oldest")&&tempMap[o2]["t"]!=tempMap[o1]["t"]){
          double currentTime = (DateTime.now().millisecondsSinceEpoch/1000.0);
          double time1 = tempMap[o1]["t"]!=null?tempMap[o1]["t"].toDouble():(currentTime/2.0).roundToDouble();
          double time2 = tempMap[o2]["t"]!=null?tempMap[o2]["t"].toDouble():(currentTime/2.0).roundToDouble();
          return sorting=="newest"?time1>time2?-1:1:time1>time2?1:-1;
        }else if(voters2!=voters1){
          return voters2-voters1;
        }else if(tempMap[o1]["q"].compareTo(tempMap[o2]["q"])!=0){
          return tempMap[o1]["q"].compareTo(tempMap[o2]["q"]);
        }
        return o1.compareTo(o2);
      }else{
        if(sorting=="newest"||sorting=="oldest"){
          return sorting=="newest"?createdPolls.indexOf(o2)-createdPolls.indexOf(o1):createdPolls.indexOf(o1)-createdPolls.indexOf(o2);
        }else{
          if(voters2!=voters1){
            return voters2-voters1;
          }else if(tempMap[o1]["q"].compareTo(tempMap[o2]["q"])!=0){
            return tempMap[o1]["q"].compareTo(tempMap[o2]["q"]);
          }
          return o1.compareTo(o2);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context){
    if(!hasLoaded){
      lastHasLoaded = false;
      return CustomScrollView(
          slivers: [
            SliverAppBar(
                pinned: false,
                backgroundColor: color,
                floating: true,
                centerTitle: false,
                expandedHeight: 30.0,
                title: Text(!widget.onlyCreated?"Browse":"Created"),
                actions: [
                  IconButton(
                      icon: Icon(Icons.search),
                      onPressed: (){}
                  ),
                  Padding(padding: EdgeInsets.only(right:3.0),child:Container(
                      width: 35.0,
                      child: PopupMenuButton<String>(
                          itemBuilder: (BuildContext context)=>widget.onlyCreated?[
                            PopupMenuItem<String>(child: const Text("Top"), value: "top"),
                            PopupMenuItem<String>(child: const Text("Newest"), value: "newest"),
                            PopupMenuItem<String>(child: const Text("Oldest"), value: "oldest")
                          ]:[
                            PopupMenuItem<String>(child: const Text("Trending"), value: "trending"),
                            PopupMenuItem<String>(child: const Text("Top"), value: "top"),
                            PopupMenuItem<String>(child: const Text("Newest"), value: "newest"),
                            PopupMenuItem<String>(child: const Text("Oldest"), value: "oldest")
                          ],
                          child: Icon(Icons.sort),
                          onSelected: (str){}
                      )
                  ))
                ],
                bottom:PreferredSize(preferredSize: Size(double.infinity,3.0),child: Container(height:3.0,child:LinearProgressIndicator(valueColor: AlwaysStoppedAnimation(indicatorColor))))
            )
          ]
      );
    }else if(sortedMap==null){
      sortMap();
    }else if(!lastHasLoaded&&unLoadedPolls.length>0){
      setState((){
        sortMap();
        unLoadedPolls=List<String>();
      });
    }
    lastHasLoaded = true;
    return Stack(
        children: [
          SafeArea(bottom:false,child:CustomScrollView(
              slivers: [
                SliverAppBar(
                    pinned: false,
                    floating: true,
                    title:!inSearch?Text(!widget.onlyCreated?"Browse":"Created"):TextField(
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(fontSize:20.0,color: Colors.white),
                        controller: c,
                        autofocus: true,
                        autocorrect: false,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Search",
                            hintStyle: TextStyle(color:Colors.white30)
                        ),
                        focusNode: f,
                        onChanged: (str){
                          search = str;
                        },
                        onSubmitted:(str){
                          s.jumpTo(0.0);
                          setState((){search = str;});
                          sortMap();
                        }
                    ),
                    centerTitle: false,
                    expandedHeight: 30.0,
                    backgroundColor: color,
                    actions: [
                      inSearch?IconButton(
                        icon: Icon(Icons.close),
                        onPressed: (){
                          if(f.hasFocus){
                            search = "";
                            s.jumpTo(0.0);
                            setState((){c.text = search;});
                            sortMap();
                          }else{
                            search = "";
                            c.text = "";
                            s.jumpTo(0.0);
                            setState((){inSearch = false;});
                            sortMap();
                          }
                        },
                      ):IconButton(
                          icon: Icon(Icons.search),
                          onPressed: (){
                            s.jumpTo(0.0);
                            setState((){inSearch = true;});
                          }
                      ),
                      Padding(padding: EdgeInsets.only(right:3.0),child:Container(
                          width: 35.0,
                          child: PopupMenuButton<String>(
                              itemBuilder: (BuildContext context)=>widget.onlyCreated?[
                                PopupMenuItem<String>(child: const Text("Top"), value: "top"),
                                PopupMenuItem<String>(child: const Text("Newest"), value: "newest"),
                                PopupMenuItem<String>(child: const Text("Oldest"), value: "oldest")
                              ]:[
                                PopupMenuItem<String>(child: const Text("Trending"), value: "trending"),
                                PopupMenuItem<String>(child: const Text("Top"), value: "top"),
                                PopupMenuItem<String>(child: const Text("Newest"), value: "newest"),
                                PopupMenuItem<String>(child: const Text("Oldest"), value: "oldest")
                              ],
                              child: Icon(Icons.sort),
                              onSelected: (str){
                                s.jumpTo(0.0);
                                setState((){
                                  sorting = str;
                                  s.jumpTo(0.0);
                                  sortMap();
                                });
                              }
                          )
                      )),
                    ]
                ),
                SliverStickyHeader(
                    header:unLoadedPolls.length>0?!loadingNewPolls?GestureDetector(onTap:() async{
                      await s.animateTo(0.0,curve: Curves.easeOut, duration: const Duration(milliseconds: 300));
                      setState((){loadingNewPolls = true;});
                      Timer(Duration(milliseconds:350),(){
                        setState((){
                          loadingNewPolls = false;
                          sortMap();
                          unLoadedPolls=List<String>();
                        });
                      });
                    },child:Container(height:30.0,color:indicatorColor,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Text("Show ${unLoadedPolls.length} Poll${unLoadedPolls.length==1?"":"s"} ",style:TextStyle(fontSize:12.5,color:Colors.white)),Icon(Icons.refresh,size:15.0,color:Colors.white)]))):Container(height:3.0,child:LinearProgressIndicator(valueColor: AlwaysStoppedAnimation(indicatorColor))):Container(height:0.0,width:0.0),
                    sliver:SliverPadding(padding: EdgeInsets.only(right:5.0,left:5.0,top:5.0),sliver:sortedMap.keys.length>0||search==null||search.length==0?SliverStaggeredGrid.countBuilder(
                      crossAxisCount: (MediaQuery.of(context).size.width/500.0).ceil(),
                      mainAxisSpacing: 0.0,
                      crossAxisSpacing: 0.0,
                      itemCount: sortedMap.keys.length,
                      itemBuilder: (BuildContext context, int i)=>Poll(sortedMap.keys.toList()[i],false),
                      staggeredTileBuilder:(i)=>StaggeredTile.fit(1),
                    ):SliverStickyHeader(
                        header:Padding(padding:EdgeInsets.only(top:10.0),child:Center(child:Text("Your search did not match any polls",textAlign:TextAlign.center,style: TextStyle(fontSize:15.0*min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)/320,color:textColor))))
                    ))
                )
              ],
              controller: s
          )),
          Positioned(
              left:0.0,top:0.0,
              child:Container(height:MediaQuery.of(context).padding.top,width:MediaQuery.of(context).size.width,color:color)
          )
        ]
    );
  }
}

class Poll extends StatefulWidget{
  final String id;
  final bool viewPage;
  final Image image;
  final double height,width;
  Poll(this.id,this.viewPage,[this.image,this.height,this.width]):super(key:ObjectKey(id));
  @override
  PollState createState() => PollState();
}

class PollState extends State<Poll>{

  bool hasImage;

  Image image;

  Completer completer;

  double height,width;

  bool multiSelect;

  bool get hasVoted => data[widget.id]["i"]!=null&&data[widget.id]["i"][userId]!=null&&(pids.length==0||lastChoice!=null||data[widget.id]["i"][userId]==-1);

  @override
  void initState(){
    super.initState();
    multiSelect = data[widget.id]["b"][0]==1;
    if(hasVoted){
      if(multiSelect&&data[widget.id]["i"]!=null&&data[widget.id]["i"][userId]!=null&&data[widget.id]["i"][userId].contains(-1)){
        choice = Set.from([]);
      }else{
        choice = !multiSelect?data[widget.id]["i"][userId]!=-1?data[widget.id]["c"][data[widget.id]["i"][userId]]:null:Set.from(data[widget.id]["i"][userId]);
      }
    }else if(multiSelect){
      choice = Set.from([]);
    }
    hasImage = data[widget.id]["b"].length==4&&data[widget.id]["b"][3]==1;
    if(hasImage){
      completer = Completer<ui.Image>();
      image = widget.image==null?Image.network(imageLink+widget.id):widget.image;
      image.image.resolve(ImageConfiguration()).addListener(ImageStreamListener((ImageInfo info, bool b){
        if(!completer.isCompleted){
          completer.complete(info.image);
        }
      }));
    }
  }

  dynamic lastChoice;

  var choice;

  List<String> pids = [];

  void vote(String c, BuildContext context, String pid, [bool b]) async{
    if(multiSelect&&((b&&choice.contains(data[widget.id]["c"].indexOf(c)))||(!b&&!choice.contains(data[widget.id]["c"].indexOf(c))))){
      try{
        setState((){pids.remove(pid);});
      }catch(e){
        pids.remove(pid);
      }
      return;
    }
    if(!multiSelect){
      lastChoice = choice;
      try{
        setState((){
          choice = c;
        });
      }catch(e){
        choice = c;
      }
    }else{
      lastChoice = Set.from([]);
      lastChoice.addAll(choice);
      try{
        setState((){
          if(b){
            choice.add(data[widget.id]["c"].indexOf(c));
          }else{
            choice.remove(data[widget.id]["c"].indexOf(c));
          }
        });
      }catch(e){
        if(b){
          choice.add(data[widget.id]["c"].indexOf(c));
        }else{
          choice.remove(data[widget.id]["c"].indexOf(c));
        }
      }
    }
    if(data[widget.id]["i"]==null){
      data[widget.id]["i"]={};
    }
    /*
    data[widget.id]["i"][userId]=!multiSelect?data[widget.id]["c"].indexOf(choice):choice.toList();
    if(multiSelect){
      data[widget.id]["i"][userId].removeWhere((i)=>i==-1);
    }
    */
    if(multiSelect){
      choice = choice.toList()..removeWhere((i)=>i==-1);
    }
    await http.put(Uri.encodeFull(database+"/data/${widget.id}/i/$userId.json?auth=$secretKey"),body: json.encode(!multiSelect?data[widget.id]["c"].indexOf(choice):(choice.length>0?choice:[-1])));
    //await http.get(Uri.encodeFull(functionsLink+"/vote?text={\"poll\":\"${widget.id}\",\"choice\":${data[widget.id]["c"].indexOf(c)},\"changed\":${!multiSelect?lastChoice!=null?data[widget.id]["c"].indexOf(lastChoice):null:!b},\"multiSelect\":$multiSelect,\"key\":\"$secretKey\"}"));
    if(multiSelect){
      choice = Set.from(choice);
    }
    try{
      setState((){pids.remove(pid);});
    }catch(e){
      pids.remove(pid);
    }
    if(widget.viewPage){
      PollViewState.canLeaveView = pids.length==0;
    }
  }

  @override
  Widget build(BuildContext context){
    if(pids.length==0&&hasVoted&&(!multiSelect?(data[widget.id]["c"].indexOf(choice)!=data[widget.id]["i"][userId]):(!IterableEquality().equals(choice.toList(),data[widget.id]["i"][userId])))){
      if(!multiSelect){
        lastChoice = data[widget.id]["i"][userId]!=-1?choice:null;
        choice = data[widget.id]["i"][userId]!=-1?data[widget.id]["c"][data[widget.id]["i"][userId]]:null;
      }else{
        lastChoice = choice;
        choice = Set.from(data[widget.id]["i"][userId]);
      }
    }else if(!multiSelect&&pids.length==0&&!hasVoted&&choice!=null){
      lastChoice = null;
      choice = null;
    }
    List correctList = data[widget.id]["a"];
    int totalVotes = correctList.reduce((n1,n2)=>n1+n2);
    Widget returnedWidget = Column(
        children:[
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding:EdgeInsets.only(top:10.0,left:11.0,right:11.0),child:Text(data[widget.id]["q"],style: TextStyle(color:textColor,fontSize: 15.0,letterSpacing:.2,fontWeight: FontWeight.w600,fontFamily: "Futura"),maxLines: !widget.viewPage?2:100,overflow: TextOverflow.ellipsis)),
                Padding(padding:EdgeInsets.only(top:5.0,left:11.0,bottom:5.0),child:Text(widget.id+(data[widget.id]["t"]!=null?" • ${timeago.format(DateTime.fromMillisecondsSinceEpoch(data[widget.id]["t"]*1000))}":"")+" • $totalVotes vote"+((totalVotes==1)?"":"s"),style: TextStyle(fontSize: 12.0,color:textColor.withOpacity(.8)))),
                image!=null?Padding(padding:EdgeInsets.only(top:5.0,bottom:5.0),child:FutureBuilder<ui.Image>(
                  future: completer.future,
                  builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot){
                    if(snapshot.hasData||height!=null||width!=null||(widget.image!=null&&widget.height!=null&&widget.width!=null)){
                      if(snapshot.hasData){
                        height = snapshot.data.height*1.0;
                        width = snapshot.data.width*1.0;
                      }
                      return GestureDetector(onTap:(){Navigator.push(context,PageRouteBuilder(opaque:false,pageBuilder:(context,a1,a2)=>ImageView(child:Center(child:PhotoView(imageProvider:image.image,minScale:min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height),maxScale:4.0*min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height))),name:widget.id)));},child:SizedBox(
                          width: double.infinity,
                          height: max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0*((MediaQuery.of(context).size.width/500.0).ceil()==1||widget.viewPage?1:3*((MediaQuery.of(context).size.width/500.0).ceil())/4)),
                          child: Image(image:image.image,fit:BoxFit.cover)
                      ));
                    }else{
                      return Container(width:double.infinity,height:max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0*((MediaQuery.of(context).size.width/500.0).ceil()==1||widget.viewPage?1:3*((MediaQuery.of(context).size.width/500.0).ceil())/4)),color:Colors.black12,child: Center(child: Container(height:MediaQuery.of(context).size.width/(15*(!widget.viewPage?(MediaQuery.of(context).size.width/500.0).ceil():1)),width:MediaQuery.of(context).size.width/(15*(!widget.viewPage?(MediaQuery.of(context).size.width/500.0).ceil():1)),child:CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(indicatorColor)))));
                    }
                  },
                )):Container(),
                Container(height:5.0),
                Column(
                    children: data[widget.id]["c"].map((c){
                      dynamic used = pids.length>0?lastChoice:choice;
                      double percent = (totalVotes!=0?correctList[data[widget.id]["c"].indexOf(c)]/totalVotes:0.0);
                      return widget.viewPage||((hasVoted&&settings[1]!="Never")||(data[widget.id]["c"].indexOf(c)<5||settings[1]=="Always"))?MaterialButton(onPressed: () async{
                        if(multiSelect||c!=choice){
                          if(widget.viewPage){
                            PollViewState.canLeaveView = false;
                          }
                          String pid;
                          do{
                            pid = "";
                            Random r = Random();
                            List<String> nums = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
                            for(int i = 0;i<8;i++){
                              pid+=(r.nextInt(2)==0?nums[r.nextInt(36)]:nums[r.nextInt(36)].toLowerCase());
                            }
                          }while(pids.contains(pid));
                          pids.add(pid);
                          waitForVote(){
                            Timer(Duration.zero,(){
                              if(pids[0]==pid){
                                vote(c,context,pid,multiSelect?!choice.contains(data[widget.id]["c"].indexOf(c)):null);
                              }else if(pids.length>0){
                                waitForVote();
                              }
                            });
                          }
                          waitForVote();
                        }else if(!multiSelect&&c==choice&&pids.length==0){
                          if(widget.viewPage){
                            PollViewState.canLeaveView = false;
                          }
                          String pid;
                          do{
                            pid = "";
                            Random r = Random();
                            List<String> nums = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
                            for(int i = 0;i<8;i++){
                              pid+=(r.nextInt(2)==0?nums[r.nextInt(36)]:nums[r.nextInt(36)].toLowerCase());
                            }
                          }while(pids.contains(pid));
                          pids.add(pid);
                          vote(null,context,pid);
                        }
                      },padding:EdgeInsets.only(top:12.0,bottom:12.0),child:Column(children: [
                        Row(
                            children: [
                              !multiSelect?(pids.length>0)&&((choice==c)||(lastChoice==c&&choice==null))?Container(width:2*kRadialReactionRadius+8.0,height:kRadialReactionRadius,child:Center(child:Container(height:16.0,width:16.0,child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(indicatorColor),strokeWidth: 2.0)))):Container(height:kRadialReactionRadius,child:Radio(
                                activeColor: indicatorColor,
                                value: c,
                                groupValue: choice,
                                onChanged: (s){
                                  if(s!=choice){
                                    if(widget.viewPage){
                                      PollViewState.canLeaveView = false;
                                    }
                                    String pid;
                                    do{
                                      pid = "";
                                      Random r = Random();
                                      List<String> nums = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
                                      for(int i = 0;i<8;i++){
                                        pid+=(r.nextInt(2)==0?nums[r.nextInt(36)]:nums[r.nextInt(36)].toLowerCase());
                                      }
                                    }while(pids.contains(pid));
                                    pids.add(pid);
                                    waitForVote(){
                                      Timer(Duration.zero,(){
                                        if(pids[0]==pid){
                                          vote(c,context,pid);
                                        }else if(pids.length>0){
                                          waitForVote();
                                        }
                                      });
                                    }
                                    waitForVote();
                                  }else if(!multiSelect&&s==choice&&pids.length==0){
                                    if(widget.viewPage){
                                      PollViewState.canLeaveView = false;
                                    }
                                    String pid;
                                    do{
                                      pid = "";
                                      Random r = Random();
                                      List<String> nums = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
                                      for(int i = 0;i<8;i++){
                                        pid+=(r.nextInt(2)==0?nums[r.nextInt(36)]:nums[r.nextInt(36)].toLowerCase());
                                      }
                                    }while(pids.contains(pid));
                                    pids.add(pid);
                                    vote(null,context,pid);
                                  }
                                },
                              )):Container(height:18.0,child:Checkbox(
                                  activeColor: indicatorColor,
                                  value: choice.contains(data[widget.id]["c"].indexOf(c)),
                                  onChanged:(b){
                                    if(widget.viewPage){
                                      PollViewState.canLeaveView = false;
                                    }
                                    String pid;
                                    do{
                                      pid = "";
                                      Random r = Random();
                                      List<String> nums = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
                                      for(int i = 0;i<8;i++){
                                        pid+=(r.nextInt(2)==0?nums[r.nextInt(36)]:nums[r.nextInt(36)].toLowerCase());
                                      }
                                    }while(pids.contains(pid));
                                    pids.add(pid);
                                    waitForVote(){
                                      Timer(Duration.zero,(){
                                        if(pids[0]==pid){
                                          vote(c,context,pid,b);
                                        }else if(pids.length>0){
                                          waitForVote();
                                        }
                                      });
                                    }
                                    waitForVote();
                                  }
                              )),
                              Expanded(child:Text(c,maxLines:!widget.viewPage?2:100,style: TextStyle(color:textColor),overflow: TextOverflow.ellipsis)),
                              Container(width:8.0)
                            ]
                        ),
                        Container(height:6.0),
                        hasVoted?Row(crossAxisAlignment: CrossAxisAlignment.center,children:[Expanded(child:Padding(padding: EdgeInsets.only(top:7.5-((MediaQuery.of(context).size.width/500.0).ceil()==1||widget.viewPage?5.0:5.0/(3*((MediaQuery.of(context).size.width/500.0).ceil())/4))/2,left:48.0,bottom:5.0),child: Container(height:(MediaQuery.of(context).size.width/500.0).ceil()==1||widget.viewPage?5.0:5.0/(3*((MediaQuery.of(context).size.width/500.0).ceil())/4),child:LinearProgressIndicator(valueColor: AlwaysStoppedAnimation((!multiSelect?used==c:used.contains(data[widget.id]["c"].indexOf(c)))?indicatorColor:settings[0]?Colors.white54:Colors.grey[600]),backgroundColor:settings[0]?Colors.white24:Colors.black26,value:percent)))),Padding(padding:EdgeInsets.only(right:8.0),child:Container(height:15.0,width:42.0,child:FittedBox(fit:BoxFit.fitHeight,alignment: Alignment.centerRight,child:Text((100*percent).toStringAsFixed(percent>=.9995?0:percent<.01?2:1)+"%",style:TextStyle(color:(used!=null&&((multiSelect&&used.contains(c))||(!multiSelect&&used==c)))?indicatorColor:textColor.withOpacity(0.8))))))]):Container()
                      ])):data[widget.id]["c"].indexOf(c)==5?/*Container(color:Colors.red,child:Text("...",style:TextStyle(fontSize:20.0,fontWeight: FontWeight.bold)))*/Icon(Icons.more_horiz):Container();
                    }).toList().cast<Widget>()
                ),
                Container(height:7.0)
              ]
            //trailing: Text(data[widget.id]["a"].reduce((n1,n2)=>n1+n2).toString(),style: TextStyle(color:Colors.black))
          )
        ]
    );
    if(widget.viewPage){
      return Container(color:!settings[0]?Color.fromRGBO(250, 250, 250, 1.0):Color.fromRGBO(32,33,36,1.0),child:returnedWidget);
    }else{
      returnedWidget = Card(color:!settings[0]?Color.fromRGBO(250, 250, 250, 1.0):Color.fromRGBO(32,33,36,1.0),child:Hero(tag:widget.id,child:Material(type:MaterialType.transparency,child:returnedWidget)));
      if(((!hasVoted||settings[1]=="Never")&&correctList.length>5)&&settings[1]!="Always"){
        returnedWidget = AbsorbPointer(child:returnedWidget);
      }
      returnedWidget = GestureDetector(onTap: (){
        if(pids.length==0){
          Navigator.push(context,PageRouteBuilder(
            pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
              return PollView(widget.id,this);
            },
            transitionDuration: Duration(milliseconds: 300),
            transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
              return FadeTransition(
                  opacity: animation,
                  child: child
              );
            },
          ));
        }
      },child:returnedWidget);
      return returnedWidget;
    }
  }
}

class PollView extends StatefulWidget{
  final String id;
  final PollState state;
  PollView(this.id,[this.state]);
  @override
  PollViewState createState() => PollViewState();
}

class PollViewState extends State<PollView>{
  static bool canLeaveView = true;
  bool canDelete;
  VoidCallback onDelete;
  bool isDeleted = false;
  bool pressedDelete = false;
  @override
  void initState(){
    super.initState();
    canDelete = currentUserLevel==1||data[widget.id]["u"]==userId||createdPolls.contains(widget.id);
    openedPoll=widget.id;
    onDelete = (){
      if(removedNotifier.value==widget.id){
        setState((){
          isDeleted = true;
        });
      }
    };
    removedNotifier.addListener(onDelete);
  }
  @override
  void dispose(){
    super.dispose();
    removedNotifier.removeListener(onDelete);
  }
  @override
  Widget build(BuildContext context){
    if(!hasLoaded){
      Future.delayed(Duration.zero,(){
        Navigator.of(context).pop();
      });
    }
    if(isDeleted&&!pressedDelete&&openedPoll==widget.id){
      Future.delayed(Duration.zero,(){
        openedPoll = null;
        Navigator.of(context).pop();
      });
    }
    return WillPopScope(onWillPop:(){
      if(!canLeaveView){
        return Future(()=>false);
      }
      if(isDeleted){
        return Future(()=>true);
      }
      if(widget.state!=null){
        widget.state.lastChoice = null;
        widget.state.choice = widget.state.multiSelect?(data[widget.id]["i"]!=null&&data[widget.id]["i"][userId]!=null?Set.from(data[widget.id]["i"][userId]):Set.from([])):(data[widget.id]["i"]!=null&&(data[widget.id]["i"][userId]!=null)?data[widget.id]["i"][userId]!=-1?data[widget.id]["c"][data[widget.id]["i"][userId]]:null:null);
      }
      return Future((){
        openedPoll=null;
        return true;
      });
    },child:Scaffold(
        body: Container(
            color: !settings[0]?Color.fromRGBO(250, 250, 250, 1.0):Color.fromRGBO(32,33,36,1.0),
            child: Stack(
                children: [
                  CustomScrollView(
                      slivers: [
                        SliverAppBar(
                            actions: [
                              canDelete?IconButton(
                                  icon:Icon(Icons.delete),
                                  onPressed:(){
                                    showDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        builder: (context){
                                          return AlertDialog(
                                              title:Text("Are you sure?",style:TextStyle(fontWeight:FontWeight.bold)),
                                              content:Text("Your poll will be permanently deleted."),
                                              actions: [
                                                FlatButton(
                                                    child: Text("No"),
                                                    onPressed: (){
                                                      Navigator.of(context).pop();
                                                    }
                                                ),
                                                FlatButton(
                                                    child: Text("Yes"),
                                                    onPressed: () async{
                                                      pressedDelete = true;
                                                      openedPoll = null;
                                                      Navigator.of(context).pop();
                                                      Navigator.of(context).pop();
                                                      if(data[widget.id]["b"].length==4&&data[widget.id]["b"][3]==1){
                                                        await http.delete(Uri.encodeFull(imageLink+widget.id));
                                                      }
                                                      await http.put(Uri.encodeFull(database+"/data/"+widget.id+".json?auth="+secretKey),body:"{}");
                                                      int lengthBefore = createdPolls.length;
                                                      createdPolls.remove(widget.id);
                                                      createdPolls.removeWhere((s)=>data[s]==null);
                                                      if(createdPolls.length!=lengthBefore){
                                                        await http.put(Uri.encodeFull(database+"/users/"+userId+"/1.json?auth="+secretKey),body:json.encode(createdPolls));
                                                      }
                                                    }
                                                )
                                              ]
                                          );
                                        }
                                    );
                                  }
                              ):Container(),
                              IconButton(
                                  icon: Icon(Icons.share),
                                  onPressed: () async{
                                    if(!isDeleted){
                                      Share.share("Vote on \""+data[widget.id]["q"]+"\" (Code: ${widget.id}) using PPoll. Use this link: https://ppoll.me/"+widget.id);
                                    }
                                  }
                              )
                            ],
                            pinned: false,
                            backgroundColor:color,
                            floating: true,
                            centerTitle: false,
                            expandedHeight: 30.0,
                            title: Text(!isDeleted?widget.id:"Poll removed"),
                            bottom: isDeleted?PreferredSize(preferredSize: Size(double.infinity,3.0),child: Container(height:3.0,child:LinearProgressIndicator(valueColor: AlwaysStoppedAnimation(indicatorColor)))):PreferredSize(preferredSize:Size(0.0,0.0),child: Container())
                        ),
                        SliverList(
                            delegate: SliverChildBuilderDelegate((context,i)=>Hero(tag:widget.id,child:!isDeleted?Material(child:widget.state!=null?Poll(widget.id,true,widget.state.image,widget.state.height,widget.state.width):Poll(widget.id,true)):Container()),childCount:1)
                        )
                      ]
                  ),
                  Positioned(
                      left:0.0,top:0.0,
                      child:Container(height:MediaQuery.of(context).padding.top,width:MediaQuery.of(context).size.width,color:color)
                  )
                ]
            )
        )
    ));
  }
}

class ImageView extends StatefulWidget{
  final Widget child;
  final String name;
  ImageView({@required this.child,@required this.name});
  @override
  ImageViewState createState() => ImageViewState();
}

class ImageViewState extends State<ImageView> with SingleTickerProviderStateMixin{
  bool hasTapped = true;
  bool isAnimating = false;
  bool hasLeft = false;
  Timer t;
  Timer t2;

  AnimationController controller;

  Animation animation;

  @override
  void initState(){
    super.initState();
    controller = AnimationController(
        duration: Duration(milliseconds: 175),
        vsync: this
    );
    animation = Tween(
        begin:0.0,
        end:1.0
    ).animate(controller);
    controller.forward();
  }

  @override
  Widget build(BuildContext context){
    if(hasTapped){
      if(t!=null&&t.isActive){
        t.cancel();
      }
      t = Timer(Duration(seconds:2),(){
        if(!isAnimating&&!hasLeft){
          setState((){isAnimating = true;});
          t2 = Timer(Duration(milliseconds: 200),(){
            if(!hasLeft){
              isAnimating = false;
              setState((){
                hasTapped = false;
              });
            }
          });
        }
      });
    }
    return FadeTransition(opacity: animation,child:GestureDetector(onTap:(){
      if(!isAnimating){
        if(hasTapped){
          if(t2!=null&&t2.isActive){
            t2.cancel();
          }
          setState((){isAnimating = true;});
          t2 = Timer(Duration(milliseconds: 200),(){
            if(!hasLeft){
              isAnimating=false;
              setState((){hasTapped=false;});
            }
          });
        }else{
          setState((){hasTapped=true;});
        }
      }
    },child:Scaffold(
        body: Stack(
            children: hasTapped?[
              widget.child,
              IgnorePointer(child:AnimatedOpacity(opacity:isAnimating?0.0:1.0,duration:Duration(milliseconds: 200),child:Container(color:Colors.black38))),
              Positioned(
                  right:10.0,
                  top:MediaQuery.of(context).padding.top,
                  child: AnimatedOpacity(opacity:isAnimating?0.0:1.0,duration:Duration(milliseconds:200),child:IconButton(iconSize:30.0*min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)/375.0,color:Colors.white,icon:Icon(Icons.close),onPressed:(){hasLeft = true;controller.animateTo(0.0).then((v){Navigator.of(context).pop();});}))
              ),
              Positioned(
                  left:15.0,
                  top:MediaQuery.of(context).padding.top+12,
                  child: IgnorePointer(child:AnimatedOpacity(opacity:isAnimating?0.0:1.0,duration:Duration(milliseconds:200),child:Text(widget.name,style:TextStyle(fontSize:(48.0/1.75)*min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)/375.0,color:Colors.white))))
              )
              //AnimatedOpacity(opacity:isAnimating?0.0:1.0,duration:Duration(milliseconds:200),child:Container(color:Colors.white70,height:MediaQuery.of(context).padding.top+kToolbarHeight,child:AppBar(actions:[IconButton(icon:Icon(Icons.close),onPressed:(){hasLeft = true;Navigator.of(context).pop();})],automaticallyImplyLeading:false,centerTitle:false,title:Text(widget.name,style:TextStyle(color:Colors.white)),backgroundColor: Colors.transparent,elevation: 0.0)))
            ]:[
              widget.child
            ]
        )
    )));
  }
}

ScrollController createController = ScrollController();

class CreatePollPage extends StatefulWidget{
  @override
  CreatePollPageState createState() => CreatePollPageState();
}

bool loadingData = false;

class CreatePollPageState extends State<CreatePollPage>{

  List<String> choices = [null,null];

  String question;

  bool multiSelect = false;

  bool public = false;

  File image;

  double height,width;

  Completer<ui.Image> completer = Completer<ui.Image>();

  bool imageLoading = false;

  bool removing = false;

  int removedIndex = -1;

  List<TextEditingController> controllers = List<TextEditingController>()..addAll([TextEditingController(),TextEditingController()]);

  TextEditingController questionController = TextEditingController();

  @override
  Widget build(BuildContext context){
    return Scaffold(resizeToAvoidBottomPadding:false,appBar:AppBar(backgroundColor:color,title:Text("Create a Poll"),actions:[IconButton(icon:Icon(removing?Icons.check:Icons.delete),onPressed: (){setState((){removing=!removing;});})]),body:Container(
        color: !settings[0]?Color.fromRGBO(230, 230, 230, 1.0):Color.fromRGBO(51,51,51,1.0),
        child: Center(
            child: ListView(
                controller: createController,
                children:[
                  Padding(padding:EdgeInsets.only(top:5.0,left:5.0,right:5.0),child:Card(
                      color: !settings[0]?Color.fromRGBO(250, 250, 250, 1.0):Color.fromRGBO(32,33,36,1.0),
                      child:Column(
                          children:[
                            Padding(padding:EdgeInsets.only(top:10.0,left:11.0,right:11.0),child:TextField(
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                  color:textColor,fontSize: 15.0,letterSpacing:.2,fontFamily: "Futura"
                              ),
                              onChanged: (s){
                                question = s;
                              },
                              onSubmitted: (s){
                                question = s;
                              },
                              decoration: InputDecoration(
                                  hintText: "Question",
                                  hintStyle: TextStyle(color:textColor.withOpacity(0.8)),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  contentPadding: EdgeInsets.only(top:12.0,bottom:12.0,left:8.0,right:8.0)
                              ),
                              controller: questionController,
                              inputFormatters: [MaxInputFormatter(200)],
                            )),
                            image!=null?Padding(padding:EdgeInsets.only(top:10.0,bottom:5.0),child:FutureBuilder<ui.Image>(
                              future: completer.future,
                              builder:(BuildContext context, AsyncSnapshot<ui.Image> snapshot){
                                if(snapshot.hasData){
                                  height = snapshot.data.height*1.0;
                                  width = snapshot.data.width*1.0;
                                  if(removing){
                                    return GestureDetector(
                                        onTap: (){
                                          setState((){
                                            image = null;
                                            height = null;
                                            width = null;
                                          });
                                          createController.jumpTo(max(0.0,createController.position.pixels-(10+MediaQuery.of(context).size.height/3.0)));
                                        },
                                        child:Container(color:Colors.grey[400],child:SizedBox(
                                            width: double.infinity,
                                            height: max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0),
                                            child: Center(
                                                child:IconButton(
                                                    onPressed:(){
                                                      setState((){
                                                        image = null;
                                                        height = null;
                                                        width = null;
                                                      });
                                                    },
                                                    icon:Icon(Icons.delete),
                                                    iconSize:MediaQuery.of(context).size.height/736.0*50,
                                                    color:Colors.black
                                                )
                                            )
                                        ))
                                    );
                                  }
                                  return GestureDetector(onTap:(){Navigator.push(context,PageRouteBuilder(opaque:false,pageBuilder: (context,a1,a2)=>ImageView(child:Center(child:PhotoView(imageProvider:Image.file(image).image,minScale: min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height),maxScale:4.0*min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height))),name:"Image")));},child:SizedBox(
                                      width: double.infinity,
                                      height: max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0),
                                      child: Image(image:Image.file(image).image,fit:BoxFit.cover)
                                  ));
                                }else{
                                  return Container(width:double.infinity,height:max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0),color:Colors.black12,child: Center(child: Container(height:MediaQuery.of(context).size.height/20.0,width:MediaQuery.of(context).size.height/20.0,child:CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(indicatorColor)))));
                                }
                              },
                            )):Container(),
                            Column(
                                children:choices.asMap().keys.map((i)=>AnimatedOpacity(opacity:removedIndex==i?0.0:1.0,duration:Duration(milliseconds:250),child:Container(key:ValueKey<int>(i),height:50.0,child:Row(
                                    children: [
                                      !removing?!multiSelect?Radio(groupValue: null,value:i,onChanged:(i){}):Checkbox(onChanged:(b){},value:false):IconButton(icon:Icon(Icons.delete),onPressed:(){
                                        if(choices.length>2&&removedIndex==-1){
                                          setState((){removedIndex=i;});
                                          Timer(Duration(milliseconds:250),(){
                                            choices.removeAt(i);controllers.removeAt(i);
                                            for(int j = 0; j<choices.length;j++){
                                              controllers[j].text = choices[j];
                                            }
                                            createController.jumpTo(max(0.0,createController.position.pixels-50));
                                            setState((){removedIndex=-1;});
                                          });
                                        }
                                      }),
                                      Expanded(
                                        child: Padding(padding:EdgeInsets.only(right:11.0),child:TextField(
                                            textCapitalization: TextCapitalization.sentences,
                                            style: TextStyle(color:textColor,fontSize:14.0),
                                            onChanged: (s){
                                              choices[i]=s;
                                            },
                                            onSubmitted: (s){
                                              choices[i]=s;
                                            },
                                            decoration: InputDecoration(
                                              hintText: "Option ${i+1}",
                                              hintStyle: TextStyle(color:textColor.withOpacity(0.7)),
                                            ),
                                            controller: controllers[i],
                                            inputFormatters: [MaxInputFormatter(100)]
                                        )),
                                      ),
                                      Container(width:5.0)
                                    ]
                                )))).toList()
                            ),
                            MaterialButton(
                                padding:EdgeInsets.zero,
                                child: Container(height:50.0,child:Row(
                                    children:[
                                      Container(width:2*kRadialReactionRadius+8.0,height:2*kRadialReactionRadius+8.0,child:Icon(Icons.add)),
                                      Expanded(child:Text("Add",style:TextStyle(color:textColor,fontSize:15.0)))
                                    ]
                                )),
                                onPressed:(){
                                  if(choices.length<20){
                                    if(createController.position.pixels>0){
                                      createController.jumpTo(createController.position.pixels+50.0);
                                    }
                                    controllers.add(TextEditingController());
                                    setState((){choices.add(null);});
                                  }
                                }
                            ),
                            Container(height:7.0)
                          ]
                      )
                  )),
                  Container(height:5.0),
                  MaterialButton(color:settings[0]?Color.fromRGBO(32,33,36,1.0):Color.fromRGBO(253,253,253,1.0),onPressed:(){setState((){multiSelect=!multiSelect;public=false;});},padding:EdgeInsets.zero,child:ListTile(leading:Text("Multiple selections",style:TextStyle(color:textColor)),trailing:Switch(value:multiSelect,activeColor:indicatorColor,onChanged:(b){setState((){multiSelect=b;public=false;});}))),
                  MaterialButton(color:settings[0]?Color.fromRGBO(32,33,36,1.0):Color.fromRGBO(253,253,253,1.0),onPressed:(){setState((){public=!public;multiSelect=false;});},padding:EdgeInsets.zero,child:ListTile(leading:Text("Publicly searchable",style:TextStyle(color:textColor)),trailing:Switch(value:public,activeColor:indicatorColor,onChanged:(b){setState((){public=b;multiSelect=false;});}))),
                  MaterialButton(color:settings[0]?Color.fromRGBO(32,33,36,1.0):Color.fromRGBO(253,253,253,1.0),onPressed:() async{
                    if(image!=null&&width!=null){
                      Navigator.push(context,PageRouteBuilder(opaque:false,pageBuilder: (context,a1,a2)=>ImageView(child:Center(child:PhotoView(imageProvider:Image.file(image).image,minScale: min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height),maxScale:4.0*min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height))),name:"Image")));
                    }else if(!imageLoading){
                      completer = Completer<ui.Image>();
                      File tempImage = await ImagePicker.pickImage(source: ImageSource.gallery);
                      if(tempImage!=null){
                        if(tempImage!=null&&(basename(tempImage.path)==null||lookupMimeType(basename(tempImage.path))==null||!["image/png","image/jpeg"].contains(lookupMimeType(basename(tempImage.path))))){
                          imageLoading=false;
                          showDialog(
                              context: context,
                              barrierDismissible: true,
                              builder: (context){
                                return AlertDialog(
                                    title:Text("Error",style:TextStyle(fontWeight:FontWeight.bold)),
                                    content:Text(basename(tempImage.path)==null?"Invalid file path":"Invalid file type"),
                                    actions: [
                                      FlatButton(
                                          child: Text("OK"),
                                          onPressed: (){
                                            Navigator.of(context).pop();
                                          }
                                      )
                                    ]
                                );
                              }
                          );
                          return;
                        }
                        setState((){imageLoading = true;image = tempImage;});
                        createController.jumpTo(createController.position.pixels+10+MediaQuery.of(context).size.height/3.0);
                        Image.file(tempImage).image.resolve(ImageConfiguration()).addListener(ImageStreamListener((ImageInfo info, bool b){
                          completer.complete(info.image);
                          height = info.image.height*1.0;
                          width = info.image.width*1.0;
                          setState((){imageLoading = false;});
                        }));
                      }else{
                        height=null;
                        width=null;
                        imageLoading=false;
                        image=null;
                      }
                    }
                  },padding:EdgeInsets.zero,child:ListTile(leading:Text(image!=null?"Image selected":"Add an image",style:TextStyle(color:textColor)),trailing:Padding(padding:EdgeInsets.only(right:10.0),child:SizedBox(height:40.0,width:40.0,child:image!=null?!imageLoading?!removing?Image.file(image,fit:BoxFit.cover):IconButton(color:settings[0]?Colors.white:Colors.black,icon: Icon(Icons.delete),onPressed:(){
                    createController.jumpTo(max(0.0,createController.position.pixels-(10+MediaQuery.of(context).size.height/3.0)));
                    setState((){
                      image = null;
                      height = null;
                      width = null;
                    });
                  }):Padding(padding:EdgeInsets.all(7.0),child:CircularProgressIndicator()):Icon(Icons.add,color:settings[0]?Colors.white:Colors.black))))),
                  Container(height:20.0),
                  Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:MaterialButton(
                      color:color,
                      height:40.0,
                      child:Text("SUBMIT",style:TextStyle(fontSize:14.0,color:Colors.white,letterSpacing:.5)),
                      onPressed:() async{
                        if(!hasLoaded){
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context){
                                return AlertDialog(
                                    title: Text("Error",style:TextStyle(fontWeight:FontWeight.bold)),
                                    content: Text("You must wait for the browse page to load before you create polls."),
                                    actions: [
                                      FlatButton(
                                          child: Text("OK"),
                                          onPressed: (){
                                            Navigator.of(context).pop();
                                          }
                                      )
                                    ]
                                );
                              }
                          );
                          return;
                        }
                        try{
                          await InternetAddress.lookup("google.com");
                        }on SocketException catch(_){
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context){
                                return AlertDialog(
                                    title: Text("Error",style:TextStyle(fontWeight:FontWeight.bold)),
                                    content: Text("Please check your internet connection"),
                                    actions: [
                                      FlatButton(
                                          child: Text("OK"),
                                          onPressed: (){
                                            Navigator.of(context).pop();
                                          }
                                      )
                                    ]
                                );
                              }
                          );
                          return;
                        }
                        bool validQuestion = question!=null&&question!="";
                        bool validChoices = !choices.contains(null)&&!choices.contains("")&&(choices.toSet().length==choices.length);
                        bool validImage;
                        if(image==null){
                          validImage = true;
                        }else{
                          validImage = ((await image.length())<5000000)&&(basename(image.path)!=null&&lookupMimeType(basename(image.path))!=null&&["image/png","image/jpeg"].contains(lookupMimeType(basename(image.path))));
                        }
                        if(validQuestion&&validChoices&&validImage){
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context){
                                return AlertDialog(
                                    title: Text("Loading"),
                                    content: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation(indicatorColor))
                                );
                              }
                          );
                          String code;
                          await http.get(Uri.encodeFull(functionsLink+"/create?text={\"key\":"+json.encode(secretKey)+",\"a\":"+json.encode(List<int>(choices.length).map((i)=>0).toList())+",\"c\":"+json.encode(choices)+",\"q\":"+json.encode(question)+",\"u\":"+json.encode(userId)+",\"b\":"+json.encode([multiSelect?1:0,0,public?1:0,image!=null?1:0])+"}").replaceAll("#","%23").replaceAll("&","%26")).then((r){
                            List l = json.decode(r.body);
                            code = l[0];
                            data[code] = l[1];
                          }).catchError((e){
                            Navigator.of(context).pop();
                            showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context){
                                  return AlertDialog(
                                      title: Text("Error",style:TextStyle(fontWeight:FontWeight.bold)),
                                      content: Text("Something went wrong"),
                                      actions: [
                                        FlatButton(
                                            child: Text("OK"),
                                            onPressed: (){
                                              Navigator.of(context).pop();
                                            }
                                        )
                                      ]
                                  );
                                }
                            );
                            throw e;
                          });
                          if(code==null){
                            return;
                          }
                          if(image!=null){
                            await http.post(Uri.encodeFull(cloudUploadDatabase+"/o?uploadType=media&name="+code),headers:{"content-type":lookupMimeType(basename(image.path))},body:await image.readAsBytes());
                          }
                          Navigator.of(context).pop();
                          createController.jumpTo(0.0);
                          choices = [null,null];
                          question = null;
                          multiSelect = false;
                          public = false;
                          image = null;
                          height = null;
                          width = null;
                          completer = Completer<ui.Image>();
                          imageLoading = false;
                          removing = false;
                          removedIndex = -1;
                          questionController = TextEditingController();
                          controllers = List<TextEditingController>()..addAll([TextEditingController(),TextEditingController()]);
                          setState((){});
                          Navigator.push(context,MaterialPageRoute(builder: (context)=>PollView(code)));
                        }else{
                          String errorMessage = "";
                          if((question==null||choices.contains(null)||question==""||choices.contains(""))&&choices.toSet().length!=choices.length){
                            errorMessage="Please complete all the fields without duplicates";
                          }else if(question==null||choices.contains(null)||question==""||choices.contains("")){
                            errorMessage="Please complete all the fields";
                          }else if(choices.toSet().length!=choices.length){
                            errorMessage="Please do not include duplicate choices";
                          }
                          if(image!=null&&((await image.length()>5000000))){
                            if(errorMessage==""){
                              errorMessage="That image is too big (max size is 5 MB)";
                            }else{
                              errorMessage+=" and reduce the image size to below 5 MB";
                            }
                          }
                          if(image!=null&&(basename(image.path)==null||lookupMimeType(basename(image.path))==null||!["image/png","image/jpeg"].contains(lookupMimeType(basename(image.path))))){
                            errorMessage+=(errorMessage==""?"Invalid image format":". The image format is invalid");
                          }
                          showDialog(
                              context: context,
                              barrierDismissible: true,
                              builder: (context){
                                return AlertDialog(
                                    title:Text("Error",style:TextStyle(fontWeight:FontWeight.bold)),
                                    content:Text(errorMessage),
                                    actions: [
                                      FlatButton(
                                          child: Text("OK"),
                                          onPressed: (){
                                            Navigator.of(context).pop();
                                          }
                                      )
                                    ]
                                );
                              }
                          );
                        }
                      }
                  )),
                  Container(height:20.0)
                ]
            )
        )
    ));
  }
}

class OpenPollPage extends StatefulWidget{
  @override
  OpenPollPageState createState() => OpenPollPageState();
}

class OpenPollPageState extends State<OpenPollPage>{

  @override
  void initState(){
    super.initState();
    f.addListener((){
      setState((){});
    });
  }

  TextEditingController openController = TextEditingController();
  FocusNode f = FocusNode();
  String input;
  @override
  Widget build(BuildContext context){
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    double usedParam = min(width,height);
    double space = f.hasFocus?0.0:(height - kBottomNavigationBarHeight);
    return Scaffold(
        resizeToAvoidBottomPadding: false,
        body: Stack(
            children:[
              Container(
                  color:!settings[0]?Color.fromRGBO(230, 230, 230, 1.0):Color.fromRGBO(51,51,51,1.0)
              ),
              SingleChildScrollView(child:Center(child:Container(height:!f.hasFocus?max(space,260.0):max(300*height/568.0,260.0),color:!settings[0]?Color.fromRGBO(230, 230, 230, 1.0):Color.fromRGBO(51,51,51,1.0),child:Center(
                  child:Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:[
                        Container(width:usedParam*3/4,child:FittedBox(fit:BoxFit.fitWidth,child:Text("PPoll"))),
                        Container(height:7.5),
                        Container(constraints:BoxConstraints.loose(Size(usedParam*3/4,48.0)),child:TextField(
                          controller:openController,
                          focusNode: f,
                          inputFormatters: [UpperCaseTextFormatter()],
                          onChanged:(s){
                            input = s;
                          },
                          onSubmitted:(s){
                            input=s;
                          },
                          textAlign:TextAlign.center,
                          style:TextStyle(
                              color:textColor,
                              fontSize:20.0
                          ),
                          decoration: InputDecoration(
                              hintText: "Poll Code",
                              border: InputBorder.none,
                              fillColor: !settings[0]?Colors.grey[400]:Colors.grey[600],
                              filled:true
                          ),
                        )),
                        Container(height:7.5),
                        Container(width:usedParam*3/4,height:48.0,child:RaisedButton(
                            color:color,
                            child:Text("Open Poll",style:TextStyle(fontSize:20.0,color:Colors.white)),
                            onPressed:() async{
                              if(!hasLoaded){
                                showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context){
                                      return AlertDialog(
                                          title: Text("Error",style:TextStyle(fontWeight:FontWeight.bold)),
                                          content: Text("You must wait for the browse page to load before you view polls."),
                                          actions: [
                                            FlatButton(
                                                child: Text("OK"),
                                                onPressed: (){
                                                  Navigator.of(context).pop();
                                                }
                                            )
                                          ]
                                      );
                                    }
                                );
                                return;
                              }
                              try{
                                await InternetAddress.lookup("google.com");
                              }on SocketException catch(_){
                                showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context){
                                      return AlertDialog(
                                          title: Text("Error",style:TextStyle(fontWeight:FontWeight.bold)),
                                          content: Text("Please check your internet connection"),
                                          actions: [
                                            FlatButton(
                                                child: Text("OK"),
                                                onPressed: (){
                                                  Navigator.of(context).pop();
                                                }
                                            )
                                          ]
                                      );
                                    }
                                );
                                return;
                              }
                              if(input==null||input.length<4){
                                Scaffold.of(context).removeCurrentSnackBar();
                                Scaffold.of(context).showSnackBar(SnackBar(duration:Duration(milliseconds:450),content:Text("Invalid code")));
                              }else if(data[input]==null){
                                Scaffold.of(context).removeCurrentSnackBar();
                                Scaffold.of(context).showSnackBar(SnackBar(duration:Duration(milliseconds:450),content:Text("Poll not found")));
                              }else if(data[input]["p"]==1&&settings[2]&&(data[input]["u"]==null||data[input]["u"]!=userId)){
                                Scaffold.of(context).removeCurrentSnackBar();
                                Scaffold.of(context).showSnackBar(SnackBar(duration:Duration(milliseconds:450),content:Text("Unsafe Poll")));
                              }else{
                                String temp = input;
                                openController = TextEditingController();
                                f.unfocus();
                                setState((){input = null;});
                                Navigator.push(context,PageRouteBuilder(
                                  pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
                                    return PollView(temp);
                                  },
                                  transitionDuration: Duration(milliseconds: 300),
                                  transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child){
                                    return FadeTransition(
                                        opacity: animation,
                                        child: child
                                    );
                                  },
                                ));
                              }
                            }
                        ))
                      ]
                  )
              )))),
              Positioned(
                  left:0.0,top:0.0,
                  child:Container(height:MediaQuery.of(context).padding.top,width:MediaQuery.of(context).size.width,color:color)
              )
            ]
        )
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter{
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue){
    return newValue.text.length>4?oldValue.copyWith(text:oldValue.text.toUpperCase().replaceAll(RegExp("[^A-Z0-9]"), "")):newValue.copyWith(text:newValue.text.toUpperCase().replaceAll(RegExp("[^A-Z0-9]"), ""));
  }
}

class MaxInputFormatter extends TextInputFormatter{
  int max;
  MaxInputFormatter(this.max);
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue){
    return newValue.text.length>max?oldValue.copyWith(text:oldValue.text):newValue.copyWith(text:newValue.text);
  }
}

class PersistentData{

  PersistentData({@required this.name, @required this.external});

  bool external;

  String name;

  Future<String> get _localPath async{
    return (external&&Platform.isAndroid)?"/storage/emulated/0/Android/data":(await getApplicationDocumentsDirectory()).path;
  }

  Future<File> get _localFile async{
    final path = await _localPath;
    return File("$path/${external?".":""}${external?"config":name}.${external?"plist":"txt"}");
  }

  Future<dynamic> readData() async{
    File file;
    try{
      file = await _localFile;
    }catch(e){
      return null;
    }
    try{
      return json.decode(await file.readAsString());
    }catch(e){
      if(e is FileSystemException){
        return null;
      }
      if(name=="createdinfo"){
        String s = await file.readAsString();
        s = json.encode(s.split(" ").toList());
        await file.writeAsString(s);
        return json.decode(s);
      }else if(name=="themeinfo"){
        String s = await file.readAsString();
        s = s.split(" ")[1];
        s = json.encode(s);
        await file.writeAsString(s);
        return json.decode(s);
      }
      return null;
    }
  }

  Future<File> writeData(dynamic data) async{
    final file = await _localFile;
    return file.writeAsString(json.encode(data));
  }

}
