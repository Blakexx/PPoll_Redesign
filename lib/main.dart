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
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:photo_view/photo_view.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:connectivity/connectivity.dart';

bool light;

PersistentData settingsData = new PersistentData(directory:"settings");

PersistentData userIdData = new PersistentData(directory:"userId");

PersistentData createdPollsData = new PersistentData(directory:"createdinfo");

int numSettings = 1;

String userId;

List<dynamic> settings;

List<dynamic> createdPolls;

Map<String,dynamic> data;

ScrollController s = new ScrollController();

bool hasLoaded = false;

Color color = const Color.fromRGBO(52,52,52,1.0);

Color textColor = const Color.fromRGBO(34, 34, 34,1.0);

ConnectivityResult current;

Connectivity connection = new Connectivity();


void main() async{
  current = await connection.checkConnectivity();
  createdPolls = await createdPollsData.readData();
  if(createdPolls==null){
    createdPolls = new List<dynamic>();
    createdPollsData.writeData(createdPolls);
  }
  settings = await settingsData.readData();
  if(settings==null){
    settings = new List<dynamic>();
  }
  if(settings.length>numSettings){
    settings = settings.sublist(0,numSettings);
    settingsData.writeData(settings);
  }else if(settings.length<numSettings){
    settings.addAll(new List<dynamic>(numSettings-settings.length).map((n)=>false));
    settingsData.writeData(settings);
  }
  userId = await userIdData.readData();
  if(userId==null){
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
    await http.put(Uri.parse(database+"/users/$userId.json?auth="+secretKey),body:"0");
    userIdData.writeData(userId);
  }
  runApp(new App());
}

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
      try{
        final result = await InternetAddress.lookup("google.com");
        if(result.isNotEmpty && result[0].rawAddress.isNotEmpty){
          data = json.decode(((await http.get(Uri.encodeFull(database+"/data.json?auth="+secretKey))).body));
          client.openUrl("GET", Uri.parse(database+"/data.json?auth="+secretKey)).then((req){
            req.headers.set("Accept", "text/event-stream");
            req.followRedirects = true;
            req.close().then((response) async{
              if(response.statusCode == 200){
                if(!hasLoaded){
                  setState((){hasLoaded = true;});
                }
                response.map((bytes)=>new String.fromCharCodes(bytes)).listen((text){
                  if(text.split(":").length>1&&text.split(":")[1].contains("keep-alive")){
                    print("Keep-alive ${watch.elapsedMilliseconds}");
                    watch.reset();
                    watch.start();
                  }else{
                    dynamic returned;
                    try{
                      returned = json.decode(text.substring (text.indexOf("{"),text.lastIndexOf("}")+1));
                    }catch(e){
                      return;
                    }
                    List<dynamic> path = returned["path"].split("/");
                    dynamic finalPath = path[path.length-1];
                    dynamic temp = data;
                    path.sublist(1,path.length-1).forEach((o){
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
                    if(index==0){
                      setState((){
                        try{
                          int i = int.parse(finalPath);
                          if(returned["data"]==null){
                            temp.remove(i);
                          }else{
                            if(temp==null){
                              temp = {};
                            }
                            temp[i] = returned["data"];
                          }
                        }catch(e){
                          if(returned["data"]==null){
                            temp.remove(finalPath);
                          }else{
                            if(temp==null){
                              temp = {};
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
                            temp = {};
                          }
                          temp[i] = returned["data"];
                        }
                      }catch(e){
                        if(returned["data"]==null){
                          temp.remove(finalPath);
                        }else{
                          if(temp==null){
                            temp = {};
                          }
                          temp[finalPath] = returned["data"];
                        }
                      }
                    }
                  }
                });
              }
            });
          });
        }
      }on SocketException catch(n){
        new Timer(new Duration(seconds:1),waitForConnection);
      }
    };
    waitForConnection();
  }

  int index = 0;

  @override
  void initState(){
    super.initState();
    /*ensureConnection(){
      new Timer(new Duration(seconds:1),() async{
        ConnectivityResult r = await connection.checkConnectivity();
        if(r!=current){
          current = r;
          setState((){
            client.close(force:true);
            hasLoaded = false;
          });
          if(r!=ConnectivityResult.none){
            try{
              final result = await InternetAddress.lookup("google.com");
              if(result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
                setUp();
              }
            }on SocketException catch(n){
              current = ConnectivityResult.none;
            }
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
          client.close(force:true);
          hasLoaded = false;
        });
        setUp(current);
      }
    });
    if(current!=ConnectivityResult.none){
      setUp(current);
    }
  }

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
              home: new Scaffold(
                  bottomNavigationBar: new BottomNavigationBar(
                      currentIndex: index,
                      type: BottomNavigationBarType.fixed,
                      fixedColor: settings[0]?Colors.deepOrangeAccent:Colors.indigoAccent,
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
                      onTap: (i){
                        if(index!=i){
                          setState((){index = i;});
                        }else if(index==0&&i==0&&hasLoaded){
                          s.animateTo(0.0,curve: Curves.easeOut, duration: const Duration(milliseconds: 300));
                        }
                      }
                  ),
                  body: index==0?new Container(
                      color: const Color.fromRGBO(230, 230, 230, 1.0),
                      child: new Center(
                          child: new View(false)
                      )
                  ):index==1?new Container(
                      color: const Color.fromRGBO(230, 230, 230, 1.0),
                      child: new Center(
                          child: new Text("New")
                      )
                  ):index==2?new Container(
                      child: new Center(
                          child: new Text("Vote")
                      )
                  ):index==3?new Container(
                      child: new Center(
                          child: new View(true)
                      )
                  ):new Container(
                      child: new Center(
                          child: new Column(
                              children: settings.asMap().keys.map((i)=>new Switch(value:settings[i],onChanged: (b){
                                setState((){settings[i]=b;});
                                settingsData.writeData(settings);
                              })).toList()
                          )
                      )
                  )
              )
          );
        },
        data: (brightness) => new ThemeData(fontFamily: "Poppins",brightness: settings!=null&&settings[0]?Brightness.dark:Brightness.light),
        defaultBrightness: settings!=null&&settings[0]?Brightness.dark:Brightness.light
    );
  }
}

class View extends StatefulWidget{
  final bool onlyCreated;
  View(this.onlyCreated);
  @override
  ViewState createState() => new ViewState();
}

class ViewState extends State<View>{

  String sorting = "newest";

  String search = "";

  bool inSearch = false;

  bool hasSearched = false;

  FocusNode f = new FocusNode();

  TextEditingController c = new TextEditingController();

  Map<String,dynamic> sortedMap;

  @override
  Widget build(BuildContext context){
    if(!hasLoaded){
      return new CustomScrollView(
        slivers: [
          new SliverAppBar(
            pinned: false,
            backgroundColor: settings[0]?Colors.deepOrange:color,
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
                      itemBuilder: (BuildContext context)=>[
                        new PopupMenuItem<String>(child: const Text("Top"), value: "top"),
                        new PopupMenuItem<String>(child: const Text("Newest"), value: "newest"),
                        new PopupMenuItem<String>(child: const Text("Oldest"), value: "oldest")
                      ],
                      child: new Icon(Icons.sort),
                      onSelected: (str){}
                  )
              ))
            ],
            bottom: new PreferredSize(preferredSize: new Size(double.infinity,3.0),child: new Container(height:3.0,child:new LinearProgressIndicator()))
          )
        ]
      );
    }
    Map<String,dynamic> tempMap = new Map<String,dynamic>()..addAll(data)..removeWhere((key,value){
      return (widget.onlyCreated&&!createdPolls.contains(key))||(!(key.toUpperCase().contains(search.toUpperCase())||((value as Map<String,dynamic>)["q"] as String).toUpperCase().contains(search.toUpperCase()))||(!widget.onlyCreated&&((((value as Map<String,dynamic>)["b"])[2]==0)||((value as Map<String,dynamic>)["b"])[0]==1||((value as Map<String,dynamic>)["b"])[1]==1)));
    });
    sortedMap = SplayTreeMap.from(tempMap,(o1,o2){
      int voters1 = tempMap[o1]["a"].reduce((n1,n2)=>n1+n2);
      int voters2 = tempMap[o2]["a"].reduce((n1,n2)=>n1+n2);
      if(!widget.onlyCreated){
        if((sorting=="newest"||sorting=="oldest")&&tempMap[o2]["t"]!=tempMap[o1]["t"]){
          return sorting=="newest"?tempMap[o2]["t"]-tempMap[o1]["t"]:tempMap[o1]["t"]-tempMap[o2]["t"];
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
    return new Stack(
      children: [
        new CustomScrollView(
            slivers: [
              new SliverAppBar(
                  pinned: false,
                  floating: true,
                  title: !inSearch?new Text(!widget.onlyCreated?"Browse":"Created"):new TextField(
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
                    },
                  ),
                  centerTitle: false,
                  expandedHeight: 30.0,
                  backgroundColor: settings[0]?Colors.deepOrange[900]:color,
                  actions: [
                    inSearch?new IconButton(
                      icon: new Icon(Icons.close),
                      onPressed: (){
                        if(f.hasFocus){
                          search = "";
                          s.jumpTo(0.0);
                          setState((){c.text = search;});
                        }else{
                          search = "";
                          c.text = "";
                          s.jumpTo(0.0);
                          setState((){inSearch = false;});
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
                            itemBuilder: (BuildContext context)=>[
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
                              });
                            }
                        )
                    )),
                  ],
              ),
              new SliverPadding(padding: new EdgeInsets.only(right:5.0,left:5.0,top:5.0),sliver:new SliverStaggeredGrid.countBuilder(
                crossAxisCount: (MediaQuery.of(context).size.width/500.0).ceil(),
                mainAxisSpacing: 0.0,
                crossAxisSpacing: 0.0,
                itemCount: sortedMap.keys.length,
                itemBuilder: (BuildContext context, int i)=>new Poll(sortedMap.keys.toList()[i]),
                staggeredTileBuilder: (i)=>new StaggeredTile.fit(1),
              )),
              //new SliverList(delegate: new SliverChildBuilderDelegate((context,i)=>new Padding(padding:EdgeInsets.only(top:i==0?5.0:0.0),child:new Poll(sortedMap.keys.toList()[i])), childCount: sortedMap.length))
            ],
          controller: s
        ),
        new Positioned(
            left:0.0,top:0.0,
            child:new Container(height:MediaQuery.of(context).padding.top,color:settings[0]?Colors.deepOrange[900]:color)
        )
      ]
    );
  }
}

class Poll extends StatefulWidget{
  final String id;
  Poll(this.id):super(key:new ObjectKey(id));
  @override
  PollState createState() => new PollState();
}

class PollState extends State<Poll>{

  bool hasVoted;

  bool hasImage;

  Image image;

  Completer completer;

  double height,width;

  bool multiSelect;

  @override
  void initState(){
    super.initState();
    multiSelect = data[widget.id]["b"][0]==1;
    hasVoted = data[widget.id]["i"]!=null&&data[widget.id]["i"][userId]!=null;
    if(hasVoted){
      choice = data[widget.id]["c"][data[widget.id]["i"][userId]];
    }
    hasImage = data[widget.id]["b"].length==4&&data[widget.id]["b"][3]==1;
    if(hasImage){
      image = new Image.network(imageLink+widget.id);
      completer = new Completer<ui.Image>();
      image.image.resolve(new ImageConfiguration()).addListener((ImageInfo info, bool b){
        if(!completer.isCompleted){
          completer.complete(info.image);
        }
      });
    }
  }

  String lastChoice;

  String choice;

  List<String> pids = [];

  void vote(String c, BuildContext context, String pid) async{
    try{
      setState(() {
        lastChoice = choice;
        choice = c;
      });
    }catch(e){
      lastChoice = choice;
      choice = c;
    }
    if(data[widget.id]["i"]==null){
      data[widget.id]["i"]={};
    }
    data[widget.id]["i"][userId]=data[widget.id]["c"].indexOf(choice);
    await http.put(Uri.encodeFull(database+"/data/${widget.id}/i/$userId.json?auth=$secretKey"),body: json.encode(data[widget.id]["i"][userId]));
    await http.get(Uri.encodeFull(functionsLink+"/vote?text={\"poll\":\"${widget.id}\",\"choice\":${data[widget.id]["c"].indexOf(choice)},\"changed\":${lastChoice!=null?data[widget.id]["c"].indexOf(lastChoice):null},\"multiSelect\":$multiSelect,\"key\":\"$secretKey\"}"));
    if(!hasVoted){
      try{
        setState((){
          hasVoted = true;
        });
      }catch(e){
        hasVoted = true;
      }
    }
    try{
      setState((){pids.remove(pid);});
    }catch(e){
      pids.remove(pid);
    }
  }

  @override
  Widget build(BuildContext context){
    return new Card(color: const Color.fromRGBO(250, 250, 250, 1.0),child: new Column(
        children:[
          new Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              new Padding(padding:EdgeInsets.only(top:10.0,left:11.0,right:11.0),child:new Text(data[widget.id]["q"],style: new TextStyle(color:textColor,fontSize: 15.0,fontWeight: FontWeight.w600),maxLines: 2,overflow: TextOverflow.ellipsis)),
              new Padding(padding:EdgeInsets.only(top:5.0,left:11.0,bottom:5.0),child:new Text(widget.id+(data[widget.id]["t"]!=null?" • ${timeago.format(new DateTime.fromMillisecondsSinceEpoch(data[widget.id]["t"]*1000))}":"")+" • ${data[widget.id]["a"].reduce((n1,n2)=>n1+n2)} vote"+((data[widget.id]["a"].reduce((n1,n2)=>n1+n2)==1)?"":"s"),style: new TextStyle(fontSize: 12.0,color:(settings[0]?Colors.white:textColor).withOpacity(.8)))),
              image!=null?new Padding(padding:EdgeInsets.only(top:5.0,bottom:5.0),child:new FutureBuilder<ui.Image>(
                future: completer.future,
                builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot){
                  if(snapshot.hasData){
                    height = snapshot.data.height*1.0;
                    width = snapshot.data.width*1.0;
                    return new GestureDetector(onTap:(){Navigator.push(context,new PageRouteBuilder(opaque:false,pageBuilder: (context,a1,a2)=>new ImageView(child:new Center(child:new PhotoView(imageProvider:image.image,minScale: min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height), maxScale:4.0*min(MediaQuery.of(context).size.width/width,MediaQuery.of(context).size.height/height))),name:widget.id)));},child:new SizedBox(
                        width: double.infinity,
                        height: max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0*((MediaQuery.of(context).size.width/500.0).ceil()==1?1:3*((MediaQuery.of(context).size.width/500.0).ceil())/4)),
                        child: new Image(image:image.image,fit:BoxFit.cover)
                    ));
                  }else{
                    return new Container(width:double.infinity,height:max(MediaQuery.of(context).size.height,MediaQuery.of(context).size.width)/(3.0*(MediaQuery.of(context).size.width/500.0).ceil()),color:Colors.black12,child: new Center(child: new Container(height:MediaQuery.of(context).size.height/20.0,width:MediaQuery.of(context).size.height/20.0,child:new CircularProgressIndicator())));
                  }
                },
              )):new Container(),
              new Column(
                  children: data[widget.id]["c"].map((c)=>new MaterialButton(onPressed: () async{
                    if(c!=choice){
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
                          }else if(pids.length>1){
                            waitForVote();
                          }
                        });
                      }
                      waitForVote();
                    }
                    },padding:EdgeInsets.zero,child:new Column(children: [
                    new Row(
                        children: [
                          pids.length>0&&choice==c?new Container(width:2*kRadialReactionRadius+8.0,height:2*kRadialReactionRadius+8.0,child:new Center(child:new Container(height:16.0,width:16.0,child: new CircularProgressIndicator(strokeWidth: 2.2)))):new Radio(
                            value: c,
                            groupValue: choice,
                            onChanged: (s){
                              if(s!=choice){
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
                                    }else if(pids.length>1){
                                      waitForVote();
                                    }
                                  });
                                }
                                waitForVote();
                              }
                            },
                          ),
                          new Expanded(child:new Text(c,maxLines:2,style: new TextStyle(color:textColor),overflow: TextOverflow.ellipsis)),
                          new Container(width:5.0)
                        ]
                    ),
                    hasVoted?new Padding(padding: EdgeInsets.only(left:50.0,right:20.0,bottom:5.0),child: new Container(height:(MediaQuery.of(context).size.width/500.0).ceil()==1?5.0:5.0/(3*((MediaQuery.of(context).size.width/500.0).ceil())/4),child:new LinearProgressIndicator(valueColor: new AlwaysStoppedAnimation(choice==c?Colors.blueAccent:Colors.grey[600]),backgroundColor:Colors.black26,value:data[widget.id]["a"][data[widget.id]["c"].indexOf(c)]/((data[widget.id]["a"].reduce((n1,n2)=>n1+n2))!=0?(data[widget.id]["a"].reduce((n1,n2)=>n1+n2)):0.0)))):new Container()
                  ]))).toList().cast<Widget>()
              ),
              new Container(height:13.0)
            ]
            //trailing: new Text(data[widget.id]["a"].reduce((n1,n2)=>n1+n2).toString(),style: new TextStyle(color:Colors.black))
          )
        ]
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
      begin: 0.0,
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

/*
settings.asMap().keys.map((i)=>new Switch(value:settings[i],onChanged: (b){
                    setState((){settings[i]=b;});
                    settingsData.writeData(settings);
                  })).toList()
 */


class PersistentData{

  PersistentData({@required this.directory});

  String directory;

  Future<String> get _localPath async {
    return (await getApplicationDocumentsDirectory()).path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return new File('$path/$directory.txt');
  }

  Future<dynamic> readData() async {
    try {
      final file = await _localFile;
      return json.decode(await file.readAsString());
    } catch (e) {
      return null;
    }
  }

  Future<File> writeData(dynamic data) async {
    final file = await _localFile;
    return file.writeAsString(json.encode(data));
  }

}

