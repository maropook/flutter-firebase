import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/config.dart';

final configurations = Configurations();

final userProvider = StateProvider((ref) {
  return FirebaseAuth.instance.currentUser;
});

final infoTextProvider = StateProvider.autoDispose((ref) {
  return '';
});

final emailProvider = StateProvider.autoDispose((ref) {
  return '';
});

final passwordProvider = StateProvider.autoDispose((ref) {
  return '';
});
final messageTextProvider = StateProvider.autoDispose((ref) {
  return '';
});

final postsQueryProvider = StreamProvider.autoDispose((ref) {
  return FirebaseFirestore.instance
      .collection('posts')
      .orderBy('date')
      .snapshots();
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: configurations.apiKey,
          appId: configurations.appId,
          messagingSenderId: configurations.messagingSenderId,
          projectId: configurations.projectId));
  runApp(ProviderScope(child: ChatApp()));
}

class ChatApp extends StatelessWidget {
  ChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoText = ref.watch(infoTextProvider);
    final email = ref.watch(emailProvider);
    final password = ref.watch(passwordProvider);
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextFormField(
            decoration: InputDecoration(labelText: 'メールアドレス'),
            onChanged: (String value) {
              ref.read(emailProvider.state).state = value;
            },
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'パスワード'),
            obscureText: true,
            onChanged: (String value) {
              ref.read(passwordProvider.state).state = value;
            },
          ),
          Container(
            padding: EdgeInsets.all(8),
            child: Text(infoText),
          ),
          Container(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final FirebaseAuth auth = FirebaseAuth.instance;
                      final result = await auth.createUserWithEmailAndPassword(
                          email: email, password: password);
                      ref.read(userProvider.state).state = result.user;
                      await Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) {
                        return ChatPage();
                      }));
                    } catch (e) {
                      ref.read(infoTextProvider.state).state =
                          "登録に失敗:${e.toString()}";
                    }
                  },
                  child: Text('ユーザ登録'))),
          const SizedBox(
            height: 8,
          ),
          Container(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed: () async {
                    try {
                      final FirebaseAuth auth = FirebaseAuth.instance;
                      final result = await auth.signInWithEmailAndPassword(
                          email: email, password: password);
                      ref.read(userProvider.state).state = result.user;
                      await Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) {
                        return ChatPage();
                      }));
                    } catch (e) {
                      ref.read(infoTextProvider.state).state =
                          "ログインに失敗しました:${e.toString()}";
                    }
                  },
                  child: Text('ログイン'))),
        ]),
      ),
    );
  }
}

class ChatPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User user = ref.watch(userProvider) as User;
    final AsyncValue<QuerySnapshot> asyncPostsQuery =
        ref.watch(postsQueryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('チャット'),
        actions: [
          IconButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                await Navigator.of(context)
                    .pushReplacement(MaterialPageRoute(builder: (context) {
                  return LoginPage();
                }));
              },
              icon: Icon(Icons.logout))
        ],
      ),
      body: Column(
        children: [
          Container(
              padding: EdgeInsets.all(8), child: Text('ログイン情報:${user.email}')),
          Expanded(
            child: asyncPostsQuery.when(data: (QuerySnapshot query) {
              return ListView(
                children: query.docs.map((document) {
                  return Card(
                    child: ListTile(
                      title: Text(document['text']),
                      subtitle: Text(document['email']),
                      trailing: document['email'] == user.email
                          ? IconButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('posts')
                                    .doc(document.id)
                                    .delete();
                              },
                              icon: Icon(Icons.delete),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              );
            }, error: (e, stackTrace) {
              return Center(child: Text(e.toString()));
            }, loading: () {
              return Center(child: Text('読み込み中・・・'));
            }),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) {
            return AddPostPage();
          }));
        },
      ),
    );
  }
}

class AddPostPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User user = ref.watch(userProvider) as User;
    final messageText = ref.watch(messageTextProvider);
    return Scaffold(
        appBar: AppBar(title: Text('チャット投稿')),
        body: Center(
          child: Container(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: '投稿メッセージ'),
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  onChanged: (String value) {
                    ref.read(messageTextProvider.state).state = value;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () async {
                        final date = DateTime.now().toLocal().toIso8601String();
                        final email = user.email;
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc()
                            .set({
                          'text': messageText,
                          'email': email,
                          'date': date
                        });
                        Navigator.of(context).pop();
                      },
                      child: Text('投稿')),
                ),
              ],
            ),
          ),
        ));
  }
}
