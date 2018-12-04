import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/widgets.dart';
import 'dart:collection';
import 'package:flutter_circular_chart/flutter_circular_chart.dart';
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

bool light;

PersistentData settingsData = new PersistentData(name:"settings",external:false);

PersistentData userIdData = new PersistentData(name:"userId",external:false);

dynamic realUserId = Platform.isAndroid?new PersistentData(name:"userId",external:true):new FlutterSecureStorage();

PersistentData createdPollsData = new PersistentData(name:"createdinfo",external:false);

PersistentData messages = new PersistentData(name:"messages",external:false);

PersistentData policy = new PersistentData(name:"privacyPolicy",external:false);

String lastMessage;

dynamic actualUserLevel;

dynamic currentUserLevel;

int numSettings = 1;

String userId;

List<dynamic> settings;

List<dynamic> createdPolls;

Map<String,dynamic> data;

ScrollController s = new ScrollController();

bool hasLoaded = false;

Color color = new Color.fromRGBO(52,52,52,1.0);

Color textColor = new Color.fromRGBO(34, 34, 34,1.0);

ConnectivityResult current;

Connectivity connection = new Connectivity();

bool agreesToPolicy = false;

int permsCount = 0;

String openedPoll;

Color indicatorColor;

int unLoadedPolls = 0;

void main() async{
  if(Platform.isAndroid){
    int count = 0;
    bool hasPerms = (await PermissionHandler().checkPermissionStatus(PermissionGroup.storage))==PermissionStatus.granted;
    while(!hasPerms){
      hasPerms = (await PermissionHandler().requestPermissions([PermissionGroup.storage]))[PermissionGroup.storage]==PermissionStatus.granted;
      if(++count==10){
        runApp(new MaterialApp(home:new Scaffold(body:new Builder(builder:(context)=>new Container(child:new Center(child:new Column(mainAxisAlignment: MainAxisAlignment.center,children:[new Padding(padding: EdgeInsets.only(left:MediaQuery.of(context).size.width*.05,right:MediaQuery.of(context).size.width*.05),child:new FittedBox(fit: BoxFit.scaleDown,child:new Text("In order to use PPoll you must enable storage permissions.",style:new TextStyle(fontSize:10000.0)))),new RichText(text:new TextSpan(text:"\nGrant Permissions",style: new TextStyle(color:Colors.blue,fontSize:20.0),recognizer: new TapGestureRecognizer()..onTap = (){
          PermissionHandler().openAppSettings();
          waitForPerms(int count) async{
            if(!hasPerms&&(await PermissionHandler().checkPermissionStatus(PermissionGroup.storage))==PermissionStatus.granted){
              hasPerms = true;
              main();
              return;
            }
            if(count==permsCount){
              new Timer(new Duration(seconds:1),(){
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
    settings = new List<dynamic>();
  }
  if(settings.length>numSettings){
    settings = settings.sublist(0,numSettings);
    await settingsData.writeData(settings);
  }else if(settings.length<numSettings){
    settings.addAll(new List<dynamic>(numSettings-settings.length).map((n)=>false));
    await settingsData.writeData(settings);
  }
  //indicatorColor = !settings[0]?new Color.fromRGBO(33,150,243,1.0):new Color.fromRGBO(100,255,218,1.0);
  indicatorColor = new Color.fromRGBO(33,150,243,1.0);
  textColor = !settings[0]?new Color.fromRGBO(34, 34, 34,1.0):Colors.white;
  color = !settings[0]?new Color.fromRGBO(52,52,52,1.0):new Color.fromRGBO(22,22,22,1.0);
  if(Platform.isIOS){
    userId = await realUserId.read(key: "PPollUserID");
    if(userId==null){
      userId = await userIdData.readData();
      if(userId!=null){
        await realUserId.write(key: "PPollUserID", value: userId);
      }
    }
  }else{
    userId = await realUserId.readData();
    if(userId==null){
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
        Random r = new Random();
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
    createdPolls=new List<dynamic>();
  }else{
    doWhenHasConnection(() async{
      createdPolls = json.decode((await http.get(Uri.encodeFull(database+"/users/$userId/1.json?auth="+secretKey))).body);
      if(createdPolls==null){
        createdPolls = await createdPollsData.readData();
        if(createdPolls!=null){
          await http.put(Uri.encodeFull(database+"/users/$userId/1.json?auth="+secretKey),body:json.encode(createdPolls));
        }else{
          createdPolls = new List<dynamic>();
        }
      }
    });
  }
  lastMessage = (await messages.readData());
  runApp(new App());
}

doWhenHasConnection(Function function) async{
  try{
    final result = await InternetAddress.lookup("google.com");
    if(result.isNotEmpty && result[0].rawAddress.isNotEmpty){
      function();
    }
  }on SocketException catch(_){
    print("Bad connection, retrying...");
    new Timer(new Duration(seconds:1),await doWhenHasConnection(function));
  }
}

bool start = true;

bool hasGotLevel = false;

class App extends StatefulWidget{
  @override
  AppState createState() => new AppState();
}

class AppState extends State<App>{

  HttpClient client = new HttpClient();

  void setUp(ConnectivityResult r) async{
    Stopwatch watch = new Stopwatch();
    watch.start();
    waitForConnection() async{
      if(r!=current){
        return;
      }
      if(userId==null||createdPolls==null){
        new Timer(new Duration(seconds:1),waitForConnection);
        return;
      }
      try{
        final result = await InternetAddress.lookup("google.com");
        if(result.isNotEmpty && result[0].rawAddress.isNotEmpty){
          data = json.decode(utf8.decode((await http.get(Uri.encodeFull(database+"/data.json?auth="+secretKey))).bodyBytes));
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
                    List<dynamic> path = returned["path"].split("/");
                    unLoadedPolls+=(path!=null&&path.length==2)&&(returned["data"]["b"][2]==1||currentUserLevel==1)&&index==0?1:0;
                    if(path!=null&&path.length==2&&returned["data"]["u"]==userId){
                      createdPolls.add(path[1]);
                      if(index==3){
                        unLoadedPolls++;
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
                          throw new Exception();
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
        new Timer(new Duration(seconds:1),waitForConnection);
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
      new Timer(new Duration(seconds:1),() async{
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
      iconCompleter = new Completer<ui.Image>();
      icon = new Image.asset("icon/platypus2.png");
      icon.image.resolve(new ImageConfiguration()).addListener((ImageInfo info, bool b){
        if(!iconCompleter.isCompleted){
          iconCompleter.complete(info.image);
        }
      });
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
    return new DynamicTheme(
        themedWidgetBuilder: (context, theme){
          return new MaterialApp(
              theme: theme,
              debugShowCheckedModeBanner: false,
              home: agreesToPolicy?new Scaffold(
                  bottomNavigationBar: new BottomNavigationBar(
                      currentIndex: index,
                      type: BottomNavigationBarType.fixed,
                      fixedColor: settings[0]?indicatorColor:Colors.indigoAccent,
                      items: [
                        BottomNavigationBarItem(
                          icon: new Icon(Icons.language),
                          title: new Text("Browse"),
                        ),
                        BottomNavigationBarItem(
                          icon: new Icon(Icons.add_circle_outline),
                          title: new Text("New"),
                        ),
                        BottomNavigationBarItem(
                          icon: new Icon(Icons.check_circle),
                          title: new Text("Vote"),
                        ),
                        BottomNavigationBarItem(
                          icon: new Icon(Icons.dehaze),
                          title: new Text("Created"),
                        ),
                        BottomNavigationBarItem(
                          icon: new Icon(Icons.settings),
                          title: new Text("Settings"),
                        ),
                      ],
                      onTap:(i){
                        unLoadedPolls = 0;
                        if(loadingData){
                          return;
                        }
                        if(index!=i){
                          setState((){index = i;});
                        }else if(((index==0&&i==0)||(index==3&&i==3))&&hasLoaded){
                          s.animateTo(0.0,curve: Curves.easeOut, duration: const Duration(milliseconds: 300));
                        }else if(index==1){
                          createController.animateTo(0.0,curve: Curves.easeOut, duration: const Duration(milliseconds: 300));
                        }
                      }
                  ),
                  body: new Builder(
                    builder: (context){
                      if(actualUserLevel==null&&!hasGotLevel){
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
                                  showDialog(context:context,barrierDismissible: false,builder:(context)=>new AlertDialog(title:new Text("You have been banned from PPoll",style:new TextStyle(fontWeight:FontWeight.bold),textAlign:TextAlign.center),content:new Text("Reason: $actualUserLevel",textAlign: TextAlign.start)));
                                }
                              });
                            }
                          }on SocketException catch(_){
                            print("Bad connection, retrying...");
                            new Timer(new Duration(seconds:1),tryToGetId);
                          }
                        }
                        tryToGetId();
                      }
                      if(start&&hasLoaded&&agreesToPolicy){
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
                              showDialog(context:context,builder:(context)=>new AlertDialog(actions: [new FlatButton(child: new Text("OK"),onPressed:(){Navigator.of(context).pop();})],title:new Text("Alert",style:new TextStyle(fontWeight:FontWeight.bold),textAlign: TextAlign.center),content:new Text(lastMessage)));
                            }
                          }
                        });
                      }
                      return index==0?new Container(
                          color: !settings[0]?new Color.fromRGBO(230, 230, 230, 1.0):new Color.fromRGBO(51,51,51,1.0),
                          child: new Center(
                              child: new View(false)
                          )
                      ):index==1?new CreatePollPage(
                      ):index==2?new OpenPollPage(
                      ):index==3?new Container(
                          color: !settings[0]?new Color.fromRGBO(230, 230, 230, 1.0):new Color.fromRGBO(51,51,51,1.0),
                          child: new Center(
                              child: new View(true)
                          )
                      ):new Scaffold(appBar:new AppBar(title:new Text("Settings"),backgroundColor: color),body:new Container(
                          color: !settings[0]?new Color.fromRGBO(230, 230, 230, 1.0):new Color.fromRGBO(51,51,51,1.0),
                          child: new Center(
                              child: new Column(
                                children: [
                                  new Padding(padding: EdgeInsets.only(top:12.0),child: new Column(
                                      children: settings.asMap().keys.map((i)=>new Padding(padding:EdgeInsets.only(bottom:12.0),child:new GestureDetector(onTap:(){
                                        bool b = !settings[0];
                                        if(i==0){
                                          //indicatorColor = !b?new Color.fromRGBO(33,150,243,1.0):new Color.fromRGBO(100,255,218,1.0);
                                          textColor = !b?new Color.fromRGBO(34,34, 34,1.0):new Color.fromRGBO(238,238,238,1.0);
                                          color = !b?new Color.fromRGBO(52,52,52,1.0):new Color.fromRGBO(22,22,22,1.0);
                                        }
                                        setState((){settings[i]=b;});
                                        settingsData.writeData(settings);
                                      },child:new Container(color:settings[0]?Colors.black:new Color.fromRGBO(253,253,253,1.0),child:new ListTile(
                                        leading: new Icon(i==0?Icons.brightness_2:Icons.settings),
                                        title: new Text(i==0?"Dark mode":"Placeholder"),
                                        trailing: new Switch(value:settings[i],onChanged:(b){
                                          if(i==0){
                                            textColor = !b?new Color.fromRGBO(34,34, 34,1.0):new Color.fromRGBO(238,238,238,1.0);
                                            color = !b?new Color.fromRGBO(52,52,52,1.0):new Color.fromRGBO(22,22,22,1.0);
                                          }
                                          setState((){settings[i]=b;});
                                          settingsData.writeData(settings);
                                        })
                                      ))))).toList()
                                  )),
                                  actualUserLevel==1?new GestureDetector(onTap:(){
                                    setState((){currentUserLevel = currentUserLevel==0?1:0;});
                                  },child:new Container(color:settings[0]?Colors.black:new Color.fromRGBO(253,253,253,1.0),child:new ListTile(
                                    leading: new Icon(Icons.stars),
                                    title: new Text("Admin"),
                                    trailing: new Switch(value: currentUserLevel==1, onChanged: (b){
                                      setState((){currentUserLevel = b?1:0;});
                                    })
                                  ))):new Container()
                                ]
                              )
                          )
                      ));
                    }
                  )
              ):new Builder(builder:(context){
                double heightOrWidth = min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height);
                double ratio = max(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)/568.0;
                bool landscape = MediaQuery.of(context).size.width>MediaQuery.of(context).size.height;
                List<Widget> widgets = [
                  new Container(height:landscape?20.0*ratio:0.0),
                  new FutureBuilder(
                    future: iconCompleter.future,
                    builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot){
                      if(snapshot.hasData){
                        if(snapshot.hasData){
                          return new Image(image:icon.image,width:heightOrWidth*5/8,height:heightOrWidth*5/8);
                        }
                      }else{
                        return new Container(
                            width:heightOrWidth*5/8,
                            height:heightOrWidth*5/8,
                            child:new Padding(
                                padding:EdgeInsets.all(heightOrWidth*5/16-25),
                                child:new CircularProgressIndicator()
                            )
                        );
                      }
                    },
                  ),
                  new Container(height:landscape?20.0*ratio:0.0),
                  new Text("Hi there!",style:new TextStyle(fontSize:25.0*ratio,color:textColor),textAlign: TextAlign.center),
                  new Text("Welcome to PPoll.",style: new TextStyle(fontSize:25.0*ratio,color:textColor),textAlign: TextAlign.center),
                  new Container(height:landscape?20.0*ratio:0.0),
                  new Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:new Text("PPoll provides a completely anonymous and ad-free experience.",style:new TextStyle(fontSize:15.0*ratio,color:textColor.withOpacity(0.9)),textAlign: TextAlign.center)),
                  new Container(height:landscape?40.0*ratio:0.0),
                  new Column(
                    children:[
                      new Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:new Center(child:new RichText(
                          textAlign:TextAlign.center,
                          text:new TextSpan(
                              children:[
                                new TextSpan(
                                  text:"By pressing the \"Get started\" button and using PPoll, you agree to our ",
                                  style: new TextStyle(color: textColor,fontSize:8.0*ratio),
                                ),
                                new TextSpan(
                                  text:"Privacy Policy",
                                  style: new TextStyle(color: Colors.blue,fontSize:8.0*ratio),
                                  recognizer: new TapGestureRecognizer()..onTap = () async{
                                    if(await canLaunch("https://platypuslabs.llc/privacypolicy")){
                                      await launch("https://platypuslabs.llc/privacypolicy");
                                    }else{
                                      throw "Could not launch $url";
                                    }
                                  },
                                ),
                                new TextSpan(
                                  text:" and ",
                                  style: new TextStyle(color: textColor,fontSize:8.0*ratio),
                                ),
                                new TextSpan(
                                  text:"Terms of Use",
                                  style: new TextStyle(color: Colors.blue,fontSize:8.0*ratio),
                                  recognizer: new TapGestureRecognizer()..onTap = () async{
                                    if(await canLaunch("https://platypuslabs.llc/termsandconditions")){
                                      await launch("https://platypuslabs.llc/termsandconditions");
                                    }else{
                                      throw "Could not launch $url";
                                    }
                                  },
                                ),
                                new TextSpan(
                                    text:".",
                                    style: new TextStyle(fontSize:8.0)
                                ),
                              ]
                          )
                      ))),
                      new Container(height:landscape?10.0*ratio:5.0*ratio),
                      new Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:new Container(width:double.infinity,child:new RaisedButton(
                          padding: EdgeInsets.all(13.0),
                          color:Colors.grey,
                          child:new Text("Get started",style:new TextStyle(fontSize:12.0*ratio)),
                          onPressed:(){
                            setState((){
                              agreesToPolicy=true;
                              policy.writeData(true);
                            });
                          }
                      )))
                    ]
                  ),
                  new Container(height:landscape?50.0*ratio:0.0),
                ];
                return new Scaffold(appBar:new AppBar(automaticallyImplyLeading:false,title:new Text("User agreement"),backgroundColor: color),body:new Container(color:!settings[0]?new Color.fromRGBO(230, 230, 230, 1.0):new Color.fromRGBO(51,51,51,1.0),child:new Center(child:!landscape?new Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,children:widgets):new ListView(children:widgets))));
              })
          );
        },
        data: (brightness) => new ThemeData(fontFamily: "Roboto",brightness: settings!=null&&settings[0]?Brightness.dark:Brightness.light),
        defaultBrightness: settings!=null&&settings[0]?Brightness.dark:Brightness.light
    );
  }
}

Timer shouldSearchTimer;

class View extends StatefulWidget{
  final bool onlyCreated;
  View(this.onlyCreated):super(key:new ObjectKey(onlyCreated));
  @override
  ViewState createState() => new ViewState();
}

class ViewState extends State<View>{

  String sorting;

  String search = "";

  bool inSearch = false;

  bool hasSearched = false;

  FocusNode f = new FocusNode();

  TextEditingController c = new TextEditingController();

  Map<String,dynamic> sortedMap;

  bool loadingNewPolls = false;

  bool lastHasLoaded = hasLoaded;

  @override
  void initState(){
    super.initState();
    sorting = widget.onlyCreated?"newest":"trending";
    c.addListener((){
      if(shouldSearchTimer!=null){
        shouldSearchTimer.cancel();
      }
      shouldSearchTimer = new Timer(new Duration(milliseconds:500),(){
        s.jumpTo(0.0);
        setState((){});
        sortMap();
      });
    });
  }

  void sortMap(){
    Map<String,dynamic> tempMap = new Map<String,dynamic>()..addAll(data)..removeWhere((key,value){
      return (widget.onlyCreated&&!createdPolls.contains(key))||(!(key.toUpperCase().contains(search.toUpperCase())||((value as Map<String,dynamic>)["q"] as String).toUpperCase().contains(search.toUpperCase()))||((!widget.onlyCreated&&currentUserLevel!=1)&&((((value as Map<String,dynamic>)["b"])[2]==0)||((value as Map<String,dynamic>)["b"])[0]==1||((value as Map<String,dynamic>)["b"])[1]==1)));
    });
    sortedMap = SplayTreeMap.from(tempMap,(o1,o2){
      int voters1 = tempMap[o1]["a"].reduce((n1,n2)=>n1+n2);
      int voters2 = tempMap[o2]["a"].reduce((n1,n2)=>n1+n2);
      if(!widget.onlyCreated){
        if(sorting=="trending"){
          double currentTime = (new DateTime.now().millisecondsSinceEpoch/1000.0);
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
          double currentTime = (new DateTime.now().millisecondsSinceEpoch/1000.0);
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
      return new CustomScrollView(
        slivers: [
          new SliverAppBar(
            pinned: false,
            backgroundColor: color,
            floating: true,
            centerTitle: false,
            expandedHeight: 30.0,
            title: new Text(!widget.onlyCreated?"Browse":"Created"),
            actions: [
              new IconButton(
                icon: new Icon(Icons.search),
                onPressed: (){}
              ),
              new Padding(padding: EdgeInsets.only(right:3.0),child:new Container(
                  width: 35.0,
                  child: new PopupMenuButton<String>(
                      itemBuilder: (BuildContext context)=>widget.onlyCreated?[
                        new PopupMenuItem<String>(child: const Text("Top"), value: "top"),
                        new PopupMenuItem<String>(child: const Text("Newest"), value: "newest"),
                        new PopupMenuItem<String>(child: const Text("Oldest"), value: "oldest")
                      ]:[
                        new PopupMenuItem<String>(child: const Text("Trending"), value: "trending"),
                        new PopupMenuItem<String>(child: const Text("Top"), value: "top"),
                        new PopupMenuItem<String>(child: const Text("Newest"), value: "newest"),
                        new PopupMenuItem<String>(child: const Text("Oldest"), value: "oldest")
                      ],
                      child: new Icon(Icons.sort),
                      onSelected: (str){}
                  )
              ))
            ],
            bottom:new PreferredSize(preferredSize: new Size(double.infinity,3.0),child: new Container(height:3.0,child:new LinearProgressIndicator(valueColor: new AlwaysStoppedAnimation(indicatorColor))))
          )
        ]
      );
    }else if(sortedMap==null){
      sortMap();
    }else if(!lastHasLoaded&&unLoadedPolls>0){
      setState((){
        sortMap();
        unLoadedPolls=0;
      });
    }
    lastHasLoaded = true;
    return new Stack(
      children: [
        new SafeArea(bottom:false,child:new CustomScrollView(
            slivers: [
              new SliverAppBar(
                pinned: false,
                floating: true,
                title:!inSearch?new Text(!widget.onlyCreated?"Browse":"Created"):new TextField(
                    textCapitalization: TextCapitalization.sentences,
                    style: new TextStyle(fontSize:20.0,color: Colors.white),
                    controller: c,
                    autofocus: true,
                    autocorrect: false,
                    decoration: new InputDecoration(
                        border: InputBorder.none,
                        hintText: "Search",
                        hintStyle: new TextStyle(color:Colors.white30)
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
                  inSearch?new IconButton(
                    icon: new Icon(Icons.close),
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
                  ):new IconButton(
                      icon: new Icon(Icons.search),
                      onPressed: (){
                        s.jumpTo(0.0);
                        setState((){inSearch = true;});
                      }
                  ),
                  new Padding(padding: EdgeInsets.only(right:3.0),child:new Container(
                      width: 35.0,
                      child: new PopupMenuButton<String>(
                          itemBuilder: (BuildContext context)=>widget.onlyCreated?[
                            new PopupMenuItem<String>(child: const Text("Top"), value: "top"),
                            new PopupMenuItem<String>(child: const Text("Newest"), value: "newest"),
                            new PopupMenuItem<String>(child: const Text("Oldest"), value: "oldest")
                          ]:[
                            new PopupMenuItem<String>(child: const Text("Trending"), value: "trending"),
                            new PopupMenuItem<String>(child: const Text("Top"), value: "top"),
                            new PopupMenuItem<String>(child: const Text("Newest"), value: "newest"),
                            new PopupMenuItem<String>(child: const Text("Oldest"), value: "oldest")
                          ],
                          child: new Icon(Icons.sort),
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
              new SliverStickyHeader(
                header:unLoadedPolls!=0?!loadingNewPolls?new GestureDetector(onTap:() async{
                  await s.animateTo(0.0,curve: Curves.easeOut, duration: const Duration(milliseconds: 300));
                  setState((){loadingNewPolls = true;});
                  new Timer(new Duration(milliseconds:350),(){
                    setState((){
                      loadingNewPolls = false;
                      sortMap();
                      unLoadedPolls=0;
                    });
                  });
                },child:new Container(height:30.0,color:indicatorColor,child:new Row(mainAxisAlignment:MainAxisAlignment.center,children:[new Text("Show $unLoadedPolls new Poll${unLoadedPolls==1?"":"s"} ",style:new TextStyle(fontSize:12.5,color:Colors.white)),new Icon(Icons.refresh,size:15.0,color:Colors.white)]))):new Container(height:3.0,child:new LinearProgressIndicator(valueColor: new AlwaysStoppedAnimation(indicatorColor))):new Container(height:0.0,width:0.0),
                sliver:new SliverPadding(padding: new EdgeInsets.only(right:5.0,left:5.0,top:5.0),sliver:sortedMap.keys.length>0||search==null||search.length==0?new SliverStaggeredGrid.countBuilder(
                  crossAxisCount: (MediaQuery.of(context).size.width/500.0).ceil(),
                  mainAxisSpacing: 0.0,
                  crossAxisSpacing: 0.0,
                  itemCount: sortedMap.keys.length,
                  itemBuilder: (BuildContext context, int i)=>new Poll(sortedMap.keys.toList()[i],false),
                  staggeredTileBuilder:(i)=>new StaggeredTile.fit(1),
                ):new SliverStickyHeader(
                    header:new Padding(padding:EdgeInsets.only(top:10.0),child:new Center(child:new Text("Your search did not match any polls",textAlign:TextAlign.center,style: new TextStyle(fontSize:15.0*min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)/320,color:textColor))))
                ))
              ),
            ],
            controller: s
        )),
        new Positioned(
            left:0.0,top:0.0,
            child:new Container(height:MediaQuery.of(context).padding.top,width:MediaQuery.of(context).size.width,color:color)
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
  Poll(this.id,this.viewPage,[this.image,this.height,this.width]):super(key:new ObjectKey(id));
  @override
  PollState createState() => new PollState();
}

class PollState extends State<Poll>{

  bool hasImage;

  Image image;

  Completer completer;

  double height,width;

  bool multiSelect;

  bool get hasVoted => data[widget.id]["i"]!=null&&data[widget.id]["i"][userId]!=null&&(pids.length==0||lastChoice!=null);

  @override
  void initState(){
    super.initState();
    multiSelect = data[widget.id]["b"][0]==1;
    if(hasVoted){
      if(multiSelect&&data[widget.id]["i"]!=null&&data[widget.id]["i"][userId]!=null&&data[widget.id]["i"][userId].contains(-1)){
        choice = new Set.from([]);
      }else{
        choice = !multiSelect?data[widget.id]["c"][data[widget.id]["i"][userId]]:new Set.from(data[widget.id]["i"][userId]);
      }
    }else if(multiSelect){
      choice = new Set.from([]);
    }
    hasImage = data[widget.id]["b"].length==4&&data[widget.id]["b"][3]==1;
    if(hasImage){
      completer = new Completer<ui.Image>();
      image = widget.image==null?new Image.network(imageLink+widget.id):widget.image;
      image.image.resolve(new ImageConfiguration()).addListener((ImageInfo info, bool b){
        if(!completer.isCompleted){
          completer.complete(info.image);
        }
      });
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
      lastChoice = new Set.from([]);
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
      choice = new Set.from(choice);
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
        lastChoice = choice;
        choice = data[widget.id]["c"][data[widget.id]["i"][userId]];
      }else{
        lastChoice = choice;
        choice = new Set.from(data[widget.id]["i"][userId]);
      }
    }
    List<int> correctList = new List.from(data[widget.id]["a"]);
    if(data[widget.id]["i"]!=null){
      for(String s in data[widget.id]["i"].keys){
        if(multiSelect&&!data[widget.id]["i"][s].contains(-1)){
          data[widget.id]["i"][s].forEach((i){
            correctList[i]++;
          });
        }else if(!multiSelect){
          correctList[data[widget.id]["i"][s]]++;
        }
      }
    }
    Widget returnedWidget = new Column(
        children:[
          new Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              new Padding(padding:EdgeInsets.only(top:10.0,left:11.0,right:11.0),child:new Text(data[widget.id]["q"],style: new TextStyle(color:textColor,fontSize: 15.0,letterSpacing:.2,fontWeight: FontWeight.w600,fontFamily: "Futura"),maxLines: !widget.viewPage?2:100,overflow: TextOverflow.ellipsis)),
              new Padding(padding:EdgeInsets.only(top:5.0,left:11.0,bottom:5.0),child:new Text(widget.id+(data[widget.id]["t"]!=null?" • ${timeago.format(new DateTime.fromMillisecondsSinceEpoch(data[widget.id]["t"]*1000))}":"")+" • ${correctList.reduce((n1,n2)=>n1+n2)} vote"+((correctList.reduce((n1,n2)=>n1+n2)==1)?"":"s"),style: new TextStyle(fontSize: 12.0,color:textColor.withOpacity(.8)))),
              image!=null?new Padding(padding:EdgeInsets.only(top:5.0,bottom:5.0),child:new FutureBuilder<ui.Image>(
                future: completer.future,
                builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot){
                  if(snapshot.hasData||height!=null||width!=null||(widget.image!=null&&widget.height!=null&&widget.width!=null)){
                    if(snapshot.hasData){
                      height = snapshot.data.height*1.0;
                      width = snapshot.data.width*1.0;
                    }
                    return new GestureDetector(onTap:(){Navigator.push(context,new PageRouteBuilder(opaque:false,pageBuilder:(context,a1,a2)=>new ImageView(child:new Center(child:new PhotoView(imageProvider:image.image,minScale:min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height),maxScale:4.0*min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height))),name:widget.id)));},child:new SizedBox(
                        width: double.infinity,
                        height: max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0*((MediaQuery.of(context).size.width/500.0).ceil()==1||widget.viewPage?1:3*((MediaQuery.of(context).size.width/500.0).ceil())/4)),
                        child: new Image(image:image.image,fit:BoxFit.cover)
                    ));
                  }else{
                    return new Container(width:double.infinity,height:max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0*((MediaQuery.of(context).size.width/500.0).ceil()==1||widget.viewPage?1:3*((MediaQuery.of(context).size.width/500.0).ceil())/4)),color:Colors.black12,child: new Center(child: new Container(height:MediaQuery.of(context).size.width/(15*(!widget.viewPage?(MediaQuery.of(context).size.width/500.0).ceil():1)),width:MediaQuery.of(context).size.width/(15*(!widget.viewPage?(MediaQuery.of(context).size.width/500.0).ceil():1)),child:new CircularProgressIndicator(valueColor: new AlwaysStoppedAnimation(indicatorColor)))));
                  }
                },
              )):new Container(),
              new Container(height:5.0),
              new Column(
                  children: data[widget.id]["c"].map((c){
                    dynamic used = pids.length>0?lastChoice:choice;
                    double percent = ((correctList.reduce((n1,n2)=>n1+n2))!=0?correctList[data[widget.id]["c"].indexOf(c)]/(correctList.reduce((n1,n2)=>n1+n2)):0.0);
                    return widget.viewPage||(hasVoted||(data[widget.id]["c"].indexOf(c)<5))?new MaterialButton(onPressed: () async{
                      if(multiSelect||c!=choice){
                        if(widget.viewPage){
                          PollViewState.canLeaveView = false;
                        }
                        String pid;
                        do{
                          pid = "";
                          Random r = new Random();
                          List<String> nums = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
                          for(int i = 0;i<8;i++){
                            pid+=(r.nextInt(2)==0?nums[r.nextInt(36)]:nums[r.nextInt(36)].toLowerCase());
                          }
                        }while(pids.contains(pid));
                        pids.add(pid);
                        waitForVote(){
                          new Timer(Duration.zero,(){
                            if(pids[0]==pid){
                              vote(c,context,pid,multiSelect?!choice.contains(data[widget.id]["c"].indexOf(c)):null);
                            }else if(pids.length>0){
                              waitForVote();
                            }
                          });
                        }
                        waitForVote();
                      }
                    },padding:EdgeInsets.only(top:12.0,bottom:12.0),child:new Column(children: [
                      new Row(
                          children: [
                            !multiSelect?pids.length>0&&choice==c?new Container(width:2*kRadialReactionRadius+8.0,height:kRadialReactionRadius,child:new Center(child:new Container(height:16.0,width:16.0,child: new CircularProgressIndicator(valueColor: new AlwaysStoppedAnimation(indicatorColor),strokeWidth: 2.0)))):new Container(height:kRadialReactionRadius,child:new Radio(
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
                                    Random r = new Random();
                                    List<String> nums = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
                                    for(int i = 0;i<8;i++){
                                      pid+=(r.nextInt(2)==0?nums[r.nextInt(36)]:nums[r.nextInt(36)].toLowerCase());
                                    }
                                  }while(pids.contains(pid));
                                  pids.add(pid);
                                  waitForVote(){
                                    new Timer(Duration.zero,(){
                                      if(pids[0]==pid){
                                        vote(c,context,pid);
                                      }else if(pids.length>0){
                                        waitForVote();
                                      }
                                    });
                                  }
                                  waitForVote();
                                }
                              },
                            )):new Container(height:18.0,child:new Checkbox(
                                activeColor: indicatorColor,
                                value: choice.contains(data[widget.id]["c"].indexOf(c)),
                                onChanged:(b){
                                  if(widget.viewPage){
                                    PollViewState.canLeaveView = false;
                                  }
                                  String pid;
                                  do{
                                    pid = "";
                                    Random r = new Random();
                                    List<String> nums = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
                                    for(int i = 0;i<8;i++){
                                      pid+=(r.nextInt(2)==0?nums[r.nextInt(36)]:nums[r.nextInt(36)].toLowerCase());
                                    }
                                  }while(pids.contains(pid));
                                  pids.add(pid);
                                  waitForVote(){
                                    new Timer(Duration.zero,(){
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
                            new Expanded(child:new Text(c,maxLines:!widget.viewPage?2:100,style: new TextStyle(color:textColor),overflow: TextOverflow.ellipsis)),
                            new Container(width:8.0)
                          ]
                      ),
                      new Container(height:6.0),
                      hasVoted?new Row(crossAxisAlignment: CrossAxisAlignment.center,children:[new Expanded(child:new Padding(padding: EdgeInsets.only(top:7.5-((MediaQuery.of(context).size.width/500.0).ceil()==1||widget.viewPage?5.0:5.0/(3*((MediaQuery.of(context).size.width/500.0).ceil())/4))/2,left:48.0,bottom:5.0),child: new Container(height:(MediaQuery.of(context).size.width/500.0).ceil()==1||widget.viewPage?5.0:5.0/(3*((MediaQuery.of(context).size.width/500.0).ceil())/4),child:new LinearProgressIndicator(valueColor: new AlwaysStoppedAnimation((!multiSelect?used==c:used.contains(data[widget.id]["c"].indexOf(c)))?indicatorColor:settings[0]?Colors.white54:Colors.grey[600]),backgroundColor:settings[0]?Colors.white24:Colors.black26,value:percent)))),new Padding(padding:EdgeInsets.only(right:8.0),child:new Container(height:15.0,width:42.0,child:new FittedBox(fit:BoxFit.fitHeight,alignment: Alignment.centerRight,child:new Text((100*percent).toStringAsFixed(percent>=.9995?0:percent<.01?2:1)+"%",style:new TextStyle(color:(used!=null&&((multiSelect&&used.contains(c))||(!multiSelect&&used==c)))?indicatorColor:textColor.withOpacity(0.8))))))]):new Container()
                    ])):data[widget.id]["c"].indexOf(c)==5?/*new Container(color:Colors.red,child:new Text("...",style:new TextStyle(fontSize:20.0,fontWeight: FontWeight.bold)))*/new Icon(Icons.more_horiz):new Container();
                  }).toList().cast<Widget>()
              ),
              new Container(height:7.0)
            ]
            //trailing: new Text(data[widget.id]["a"].reduce((n1,n2)=>n1+n2).toString(),style: new TextStyle(color:Colors.black))
          )
        ]
    );
    if(widget.viewPage){
      return new Container(color:!settings[0]?new Color.fromRGBO(250, 250, 250, 1.0):new Color.fromRGBO(32,33,36,1.0),child:returnedWidget);
    }else{
      returnedWidget = new Card(color:!settings[0]?new Color.fromRGBO(250, 250, 250, 1.0):new Color.fromRGBO(32,33,36,1.0),child:new Hero(tag:widget.id,child:new Material(type:MaterialType.transparency,child:returnedWidget)));
      if(!(hasVoted||correctList.length<6)){
        returnedWidget = new AbsorbPointer(child:returnedWidget);
      }
      returnedWidget = new GestureDetector(onTap: (){
        if(pids.length==0){
          Navigator.push(context,new PageRouteBuilder(
            pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
              return new PollView(widget.id,this);
            },
            transitionDuration: new Duration(milliseconds: 300),
            transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
              return new FadeTransition(
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
  PollViewState createState() => new PollViewState();
}

class PollViewState extends State<PollView>{
  static bool canLeaveView = true;
  @override
  void initState(){
    super.initState();
    openedPoll=widget.id;
  }
  @override
  Widget build(BuildContext context){
    if(!hasLoaded){
      Navigator.of(context).pop();
    }
    return new WillPopScope(onWillPop:(){
      if(!canLeaveView){
        return new Future(()=>false);
      }
      if(widget.state!=null){
        widget.state.lastChoice = null;
        widget.state.choice = widget.state.multiSelect?(data[widget.id]["i"]!=null&&data[widget.id]["i"][userId]!=null?new Set.from(data[widget.id]["i"][userId]):new Set.from([])):(data[widget.id]["i"]!=null&&(data[widget.id]["i"][userId]!=null)?data[widget.id]["c"][data[widget.id]["i"][userId]]:null);
      }
      return new Future((){
        openedPoll=null;
        return true;
      });
    },child:new Scaffold(
        body: new Container(
            color: !settings[0]?new Color.fromRGBO(250, 250, 250, 1.0):new Color.fromRGBO(32,33,36,1.0),
            child: new Stack(
              children: [
                new CustomScrollView(
                    slivers: [
                      new SliverAppBar(
                          actions: [new IconButton(
                            icon: new Icon(Icons.share),
                            onPressed: (){
                              Share.share("Vote on \""+data[widget.id]["q"]+"\" (Code: ${widget.id}) using PPoll. Download now at https://platypuslabs.llc/downloadppoll");
                            }
                          )],
                          pinned: false,
                          backgroundColor:color,
                          floating: true,
                          centerTitle: false,
                          expandedHeight: 30.0,
                          title: new Text(widget.id)
                      ),
                      new SliverList(
                          delegate: new SliverChildBuilderDelegate((context,i)=>new Hero(tag:widget.id,child:new Material(child:widget.state!=null?new Poll(widget.id,true,widget.state.image,widget.state.height,widget.state.width):new Poll(widget.id,true))),childCount:1)
                      )
                    ]
                ),
                new Positioned(
                    left:0.0,top:0.0,
                    child:new Container(height:MediaQuery.of(context).padding.top,width:MediaQuery.of(context).size.width,color:color)
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
  ImageViewState createState() => new ImageViewState();
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
    controller = new AnimationController(
    duration: new Duration(milliseconds: 175),
    vsync: this
    );
    animation = new Tween(
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
      t = new Timer(new Duration(seconds:2),(){
        if(!isAnimating&&!hasLeft){
          setState((){isAnimating = true;});
          t2 = new Timer(new Duration(milliseconds: 200),(){
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
    return new FadeTransition(opacity: animation,child:new GestureDetector(onTap:(){
      if(!isAnimating){
        if(hasTapped){
          if(t2!=null&&t2.isActive){
            t2.cancel();
          }
          setState((){isAnimating = true;});
          t2 = new Timer(new Duration(milliseconds: 200),(){
            if(!hasLeft){
              isAnimating=false;
              setState((){hasTapped=false;});
            }
          });
        }else{
          setState((){hasTapped=true;});
        }
      }
    },child:new Scaffold(
        body: new Stack(
            children: hasTapped?[
              widget.child,
              new IgnorePointer(child:new AnimatedOpacity(opacity:isAnimating?0.0:1.0,duration:new Duration(milliseconds: 200),child:new Container(color:Colors.black38))),
              new Positioned(
                  right:10.0,
                  top:MediaQuery.of(context).padding.top,
                  child: new AnimatedOpacity(opacity:isAnimating?0.0:1.0,duration:new Duration(milliseconds:200),child:new IconButton(iconSize:30.0*min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)/375.0,color:Colors.white,icon:new Icon(Icons.close),onPressed:(){hasLeft = true;controller.animateTo(0.0).then((v){Navigator.of(context).pop();});}))
              ),
              new Positioned(
                  left:15.0,
                  top:MediaQuery.of(context).padding.top+12,
                  child: new IgnorePointer(child:new AnimatedOpacity(opacity:isAnimating?0.0:1.0,duration:new Duration(milliseconds:200),child:new Text(widget.name,style:new TextStyle(fontSize:(48.0/1.75)*min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)/375.0,color:Colors.white))))
              )
              //new AnimatedOpacity(opacity:isAnimating?0.0:1.0,duration:new Duration(milliseconds:200),child:new Container(color:Colors.white70,height:MediaQuery.of(context).padding.top+kToolbarHeight,child:new AppBar(actions:[new IconButton(icon:new Icon(Icons.close),onPressed:(){hasLeft = true;Navigator.of(context).pop();})],automaticallyImplyLeading:false,centerTitle:false,title:new Text(widget.name,style:new TextStyle(color:Colors.white)),backgroundColor: Colors.transparent,elevation: 0.0)))
            ]:[
              widget.child
            ]
        )
    )));
  }
}

ScrollController createController = new ScrollController();

class CreatePollPage extends StatefulWidget{
  @override
  CreatePollPageState createState() => new CreatePollPageState();
}

bool loadingData = false;

class CreatePollPageState extends State<CreatePollPage>{

  List<String> choices = [null,null];

  String question;

  bool multiSelect = false;

  bool public = false;

  File image;

  double height,width;

  Completer<ui.Image> completer = new Completer<ui.Image>();

  bool imageLoading = false;

  bool removing = false;

  int removedIndex = -1;

  List<TextEditingController> controllers = new List<TextEditingController>()..addAll([new TextEditingController(),new TextEditingController()]);

  TextEditingController questionController = new TextEditingController();

  @override
  Widget build(BuildContext context){
    return new Scaffold(resizeToAvoidBottomPadding:false,appBar:new AppBar(backgroundColor:color,title:new Text("Create a Poll"),actions:[new IconButton(icon:new Icon(removing?Icons.check:Icons.delete),onPressed: (){setState((){removing=!removing;});})]),body:new Container(
        color: !settings[0]?new Color.fromRGBO(230, 230, 230, 1.0):new Color.fromRGBO(51,51,51,1.0),
        child: new Center(
            child: new ListView(
              controller: createController,
              children:[
                new Padding(padding:EdgeInsets.only(top:5.0,left:5.0,right:5.0),child:new Card(
                  color: !settings[0]?new Color.fromRGBO(250, 250, 250, 1.0):new Color.fromRGBO(32,33,36,1.0),
                  child:new Column(
                    children:[
                      new Padding(padding:EdgeInsets.only(top:10.0,left:11.0,right:11.0),child:new TextField(
                        textCapitalization: TextCapitalization.sentences,
                        style: new TextStyle(
                          color:textColor,fontSize: 15.0,letterSpacing:.2,fontFamily: "Futura"
                        ),
                        onChanged: (s){
                          question = s;
                        },
                        onSubmitted: (s){
                          question = s;
                        },
                        decoration: new InputDecoration(
                            hintText: "Question",
                            hintStyle: new TextStyle(color:textColor.withOpacity(0.8)),
                            border: new OutlineInputBorder(),
                            filled: true,
                            contentPadding: EdgeInsets.only(top:12.0,bottom:12.0,left:8.0,right:8.0)
                        ),
                        controller: questionController,
                        inputFormatters: [new MaxInputFormatter(200)],
                      )),
                      image!=null?new Padding(padding:EdgeInsets.only(top:5.0,bottom:5.0),child:new FutureBuilder<ui.Image>(
                        future: completer.future,
                        builder:(BuildContext context, AsyncSnapshot<ui.Image> snapshot){
                          if(snapshot.hasData){
                            height = snapshot.data.height*1.0;
                            width = snapshot.data.width*1.0;
                            if(removing){
                              return new GestureDetector(
                                onTap: (){
                                  setState((){
                                    image = null;
                                    height = null;
                                    width = null;
                                  });
                                  createController.jumpTo(max(0.0,createController.position.pixels-(10+MediaQuery.of(context).size.height/3.0)));
                                },
                                child:new Container(color:Colors.grey[400],child:new SizedBox(
                                  width: double.infinity,
                                  height: max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0),
                                  child: new Center(
                                    child:new IconButton(
                                      onPressed:(){
                                        setState((){
                                          image = null;
                                          height = null;
                                          width = null;
                                        });
                                      },
                                      icon:new Icon(Icons.delete),
                                      iconSize:MediaQuery.of(context).size.height/736.0*50,
                                      color:Colors.black
                                    )
                                  )
                                ))
                              );
                            }
                            return new GestureDetector(onTap:(){Navigator.push(context,new PageRouteBuilder(opaque:false,pageBuilder: (context,a1,a2)=>new ImageView(child:new Center(child:new PhotoView(imageProvider:new Image.file(image).image,minScale: min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height),maxScale:4.0*min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height))),name:"Image")));},child:new SizedBox(
                                width: double.infinity,
                                height: max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0),
                                child: new Image(image:new Image.file(image).image,fit:BoxFit.cover)
                            ));
                          }else{
                            return new Container(width:double.infinity,height:max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0),color:Colors.black12,child: new Center(child: new Container(height:MediaQuery.of(context).size.height/20.0,width:MediaQuery.of(context).size.height/20.0,child:new CircularProgressIndicator(valueColor: new AlwaysStoppedAnimation(indicatorColor)))));
                          }
                        },
                      )):new Container(),
                      new Column(
                        children:choices.asMap().keys.map((i)=>new AnimatedOpacity(opacity:removedIndex==i?0.0:1.0,duration:new Duration(milliseconds:250),child:new Container(key:new ObjectKey(i),height:50.0,child:new Row(
                            children: [
                              !removing?!multiSelect?new Radio(groupValue: null,value:i,onChanged:(i){}):new Checkbox(onChanged:(b){},value:false):new IconButton(icon:new Icon(Icons.delete),onPressed:(){
                                if(choices.length>2&&removedIndex==-1){
                                  setState((){removedIndex=i;});
                                  new Timer(new Duration(milliseconds:250),(){
                                    choices.removeAt(i);controllers.removeAt(i);
                                    for(int j = 0; j<choices.length;j++){
                                      controllers[j].text = choices[j];
                                    }
                                    createController.jumpTo(max(0.0,createController.position.pixels-50));
                                    setState((){removedIndex=-1;});
                                  });
                                }
                              }),
                              new Expanded(
                                  child: new Padding(padding:EdgeInsets.only(right:11.0),child:new TextField(
                                    textCapitalization: TextCapitalization.sentences,
                                    style: new TextStyle(color:textColor,fontSize:14.0),
                                    onChanged: (s){
                                      choices[i]=s;
                                    },
                                    onSubmitted: (s){
                                      choices[i]=s;
                                    },
                                    decoration: new InputDecoration(
                                      hintText: "Option ${i+1}",
                                      hintStyle: new TextStyle(color:textColor.withOpacity(0.7)),
                                    ),
                                    controller: controllers[i],
                                    inputFormatters: [new MaxInputFormatter(100)]
                                  )),
                              ),
                              new Container(width:5.0)
                            ]
                        )))).toList()
                      ),
                      new MaterialButton(
                        padding:EdgeInsets.zero,
                        child: new Container(height:50.0,child:new Row(
                          children:[
                            new Container(width:2*kRadialReactionRadius+8.0,height:2*kRadialReactionRadius+8.0,child:new Icon(Icons.add)),
                            new Expanded(child:new Text("Add",style:new TextStyle(color:textColor,fontSize:15.0)))
                          ]
                        )),
                        onPressed:(){
                          if(choices.length<20){
                            if(createController.position.pixels>0){
                              createController.jumpTo(createController.position.pixels+50.0);
                            }
                            controllers.add(new TextEditingController());
                            setState((){choices.add(null);});
                          }
                        }
                      ),
                      new Container(height:7.0)
                    ]
                  )
                )),
                new Container(height:5.0),
                new MaterialButton(color:settings[0]?new Color.fromRGBO(32,33,36,1.0):new Color.fromRGBO(253,253,253,1.0),onPressed:(){setState((){multiSelect=!multiSelect;public=false;});},padding:EdgeInsets.zero,child:new ListTile(leading:new Text("Multiple selections",style:new TextStyle(color:textColor)),trailing:new Switch(value:multiSelect,onChanged:(b){setState((){multiSelect=b;public=false;});}))),
                new MaterialButton(color:settings[0]?new Color.fromRGBO(32,33,36,1.0):new Color.fromRGBO(253,253,253,1.0),onPressed:(){setState((){public=!public;multiSelect=false;});},padding:EdgeInsets.zero,child:new ListTile(leading:new Text("Publicly searchable",style:new TextStyle(color:textColor)),trailing:new Switch(value:public,onChanged:(b){setState((){public=b;multiSelect=false;});}))),
                new MaterialButton(color:settings[0]?new Color.fromRGBO(32,33,36,1.0):new Color.fromRGBO(253,253,253,1.0),onPressed:() async{
                  if(image!=null&&width!=null){
                    Navigator.push(context,new PageRouteBuilder(opaque:false,pageBuilder: (context,a1,a2)=>new ImageView(child:new Center(child:new PhotoView(imageProvider:new Image.file(image).image,minScale: min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height),maxScale:4.0*min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height))),name:"Image")));
                  }else if(!imageLoading){
                    completer = new Completer<ui.Image>();
                    File tempImage = await ImagePicker.pickImage(source: ImageSource.gallery);
                    if(tempImage!=null){
                      if(tempImage!=null&&(basename(tempImage.path)==null||lookupMimeType(basename(tempImage.path))==null||!["image/png","image/jpeg"].contains(lookupMimeType(basename(tempImage.path))))){
                        imageLoading=false;
                        showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (context){
                              return new AlertDialog(
                                  title:new Text("Error",style:new TextStyle(fontWeight:FontWeight.bold)),
                                  content:new Text(basename(tempImage.path)==null?"Invalid file path":"Invalid file type"),
                                  actions: [
                                    new FlatButton(
                                        child: new Text("OK"),
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
                      new Image.file(tempImage).image.resolve(new ImageConfiguration()).addListener((ImageInfo info, bool b){
                        completer.complete(info.image);
                        height = info.image.height*1.0;
                        width = info.image.width*1.0;
                        setState((){imageLoading = false;});
                      });
                    }else{
                      height=null;
                      width=null;
                      imageLoading=false;
                      image=null;
                    }
                  }
                },padding:EdgeInsets.zero,child:new ListTile(leading:new Text(image!=null?"Image selected":"Add an image",style:new TextStyle(color:textColor)),trailing:new Padding(padding:EdgeInsets.only(right:10.0),child:new SizedBox(height:40.0,width:40.0,child:image!=null?!imageLoading?!removing?new Image.file(image,fit:BoxFit.cover):new IconButton(color:settings[0]?Colors.white:Colors.black,icon: new Icon(Icons.delete),onPressed:(){
                  createController.jumpTo(max(0.0,createController.position.pixels-(10+MediaQuery.of(context).size.height/3.0)));
                  setState((){
                    image = null;
                    height = null;
                    width = null;
                  });
                }):new Padding(padding:EdgeInsets.all(7.0),child:new CircularProgressIndicator()):new Icon(Icons.add,color:settings[0]?Colors.white:Colors.black))))),
                new Container(height:20.0),
                new Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:new MaterialButton(
                  color:color,
                  height:40.0,
                  child:new Text("SUBMIT",style:new TextStyle(fontSize:14.0,color:Colors.white,letterSpacing:.5)),
                  onPressed:() async{
                    if(!hasLoaded){
                      showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context){
                            return new AlertDialog(
                                title: new Text("Error",style:new TextStyle(fontWeight:FontWeight.bold)),
                                content: new Text("You must wait for the browse page to load before you create polls."),
                                actions: [
                                  new FlatButton(
                                      child: new Text("OK"),
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
                            return new AlertDialog(
                                title: new Text("Error",style:new TextStyle(fontWeight:FontWeight.bold)),
                                content: new Text("Please check your internet connection"),
                                actions: [
                                  new FlatButton(
                                      child: new Text("OK"),
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
                            return new AlertDialog(
                                title: new Text("Loading"),
                                content: new LinearProgressIndicator(valueColor: new AlwaysStoppedAnimation(indicatorColor))
                            );
                          }
                      );
                      String code;
                      await http.get(Uri.encodeFull(functionsLink+"/create?text={\"key\":"+json.encode(secretKey)+",\"a\":"+json.encode(new List<int>(choices.length).map((i)=>0).toList())+",\"c\":"+json.encode(choices)+",\"q\":"+json.encode(question)+",\"u\":"+json.encode(userId)+",\"b\":"+json.encode([multiSelect?1:0,0,public?1:0,image!=null?1:0])+"}").replaceAll("#","%23").replaceAll("&","%26")).then((r){
                        List l = json.decode(r.body);
                        code = l[0];
                        data[code] = l[1];
                      }).catchError((e){
                        Navigator.of(context).pop();
                        showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context){
                              return new AlertDialog(
                                  title: new Text("Error",style:new TextStyle(fontWeight:FontWeight.bold)),
                                  content: new Text("Something went wrong"),
                                  actions: [
                                    new FlatButton(
                                        child: new Text("OK"),
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
                      completer = new Completer<ui.Image>();
                      imageLoading = false;
                      removing = false;
                      removedIndex = -1;
                      questionController = new TextEditingController();
                      controllers = new List<TextEditingController>()..addAll([new TextEditingController(),new TextEditingController()]);
                      setState((){});
                      Navigator.push(context,new MaterialPageRoute(builder: (context)=>new PollView(code)));
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
                            return new AlertDialog(
                                title:new Text("Error",style:new TextStyle(fontWeight:FontWeight.bold)),
                                content:new Text(errorMessage),
                                actions: [
                                  new FlatButton(
                                      child: new Text("OK"),
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
                new Container(height:20.0)
              ]
            )
        )
    ));
  }
}

class OpenPollPage extends StatefulWidget{
  @override
  OpenPollPageState createState() => new OpenPollPageState();
}

class OpenPollPageState extends State<OpenPollPage>{
  TextEditingController openController = new TextEditingController();
  FocusNode f = new FocusNode();
  String input;
  @override
  Widget build(BuildContext context){
    double usedParam = min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height);
    return new Scaffold(
      resizeToAvoidBottomPadding: false,
      body:new Stack(
        children:[
          new Container(color:!settings[0]?new Color.fromRGBO(230, 230, 230, 1.0):new Color.fromRGBO(51,51,51,1.0),child:new Center(
              child:new Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:[
                    new Container(width:usedParam*3/4,child:new FittedBox(fit:BoxFit.fitWidth,child:new Text("PPoll"))),
                    new Container(height:7.5),
                    new Container(constraints:BoxConstraints.loose(new Size(usedParam*3/4,48.0)),child:new TextField(
                      controller:openController,
                      focusNode: f,
                      inputFormatters: [new UpperCaseTextFormatter()],
                      onChanged:(s){
                        input=s;
                      },
                      onSubmitted:(s){
                        input=s;
                      },
                      textAlign:TextAlign.center,
                      style:new TextStyle(
                          color:textColor,
                          fontSize:20.0
                      ),
                      decoration: new InputDecoration(
                          hintText: "Poll Code",
                          border: InputBorder.none,
                          fillColor: !settings[0]?Colors.grey[400]:Colors.grey[600],
                          filled:true
                      ),
                    )),
                    new Container(height:7.5),
                    new Container(width:usedParam*3/4,height:48.0,child:new RaisedButton(
                        color:color,
                        child:new Text("Open Poll",style:new TextStyle(fontSize:20.0,color:Colors.white)),
                        onPressed:() async{
                          if(!hasLoaded){
                            showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context){
                                  return new AlertDialog(
                                      title: new Text("Error",style:new TextStyle(fontWeight:FontWeight.bold)),
                                      content: new Text("You must wait for the browse page to load before you view polls."),
                                      actions: [
                                        new FlatButton(
                                            child: new Text("OK"),
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
                                  return new AlertDialog(
                                      title: new Text("Error",style:new TextStyle(fontWeight:FontWeight.bold)),
                                      content: new Text("Please check your internet connection"),
                                      actions: [
                                        new FlatButton(
                                            child: new Text("OK"),
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
                            Scaffold.of(context).showSnackBar(new SnackBar(duration:new Duration(milliseconds:450),content:new Text("Invalid code")));
                          }else if(data[input]==null){
                            Scaffold.of(context).removeCurrentSnackBar();
                            Scaffold.of(context).showSnackBar(new SnackBar(duration:new Duration(milliseconds:450),content:new Text("Poll not found")));
                          }else{
                            String temp = input;
                            openController = new TextEditingController();
                            f = new FocusNode();
                            setState((){input = null;});
                            Navigator.push(context,new PageRouteBuilder(
                              pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
                                return new PollView(temp);
                              },
                              transitionDuration: new Duration(milliseconds: 300),
                              transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child){
                                return new FadeTransition(
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
          )),
          new Positioned(
              left:0.0,top:0.0,
              child:new Container(height:MediaQuery.of(context).padding.top,width:MediaQuery.of(context).size.width,color:color)
          )
        ]
      )
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter{
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue){
    return newValue.text.length>4?oldValue.copyWith(text:oldValue.text.toUpperCase().replaceAll(new RegExp("[^A-Z0-9]"), "")):newValue.copyWith(text:newValue.text.toUpperCase().replaceAll(new RegExp("[^A-Z0-9]"), ""));
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
    return new File("$path/${external?".":""}${external?"config":name}.${external?"plist":"txt"}");
  }

  Future<dynamic> readData() async{
    try{
      final file = await _localFile;
      return json.decode(await file.readAsString());
    }catch(e){
      return null;
    }
  }

  Future<File> writeData(dynamic data) async{
    final file = await _localFile;
    return file.writeAsString(json.encode(data));
  }

}

