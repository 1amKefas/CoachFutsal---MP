import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:appcoachfutsal/fitur/kriteria/list_kriteria.dart';
import 'dart:async';
import 'package:appcoachfutsal/fitur/player/player_list_page.dart';
import 'package:appcoachfutsal/SplashScreen/splash2.dart';

// Update Page Profile
import 'package:appcoachfutsal/fitur/profile/profile_page.dart';

// Update Aspek Penilaian Page
import 'package:appcoachfutsal/fitur/aspek/aspek_penilaian_page.dart';

// Update Hasil Penilaian Page
import 'package:appcoachfutsal/fitur/penilaian/hasil_penilaian_page.dart';

import 'package:appcoachfutsal/fitur/lineup/LineUp_page.dart';
import 'package:appcoachfutsal/fitur/statistik/statistic_pemain.dart';
import 'package:appcoachfutsal/fitur/jadwal/atur_jadwal_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> getUserName() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.data()?['username'] ?? 'User';
    }
  }
  return 'User';
}

String _bulanIndo(int bulan) {
  const bulanIndo = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  return bulanIndo[bulan];
}

// Fungsi utilitas untuk mempersingkat nama lokasi
String _shortenLocation(String location, {int maxLength = 24}) {
  if (location.length <= maxLength) return location;
  List<String> parts = location.split(',');
  String short = parts.take(2).join(',').trim();
  if (short.length > maxLength) {
    short = short.substring(0, maxLength);
  }
  return short + "...";
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: FutureBuilder<String>(
                            future: getUserName(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Text('Hello,\nLoading...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
                              } else if (snapshot.hasError) {
                                return Text('Hello,\nError', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
                              } else {
                                return Text(
                                  'Hello,\n${snapshot.data}',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                );
                              }
                            },
                          )
                      ),

                      // Carousel Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 12),
                        child: SizedBox(
                          height: 180,
                          child: _DashboardCarousel(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Fitur section
                      sectionTitle('Fitur'),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: SizedBox(
                          height: 90,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              fiturCard(Icons.calendar_month, 'Atur Jadwal', context),
                              fiturCard(Icons.person_2, 'Data Pemain', context),
                              fiturCard(Icons.track_changes, 'Data Aspek', context),
                              fiturCard(Icons.sports_soccer, 'Data Kriteria', context),
                              fiturCard(Icons.fact_check, 'Penilaian', context),
                              fiturCard(Icons.stacked_bar_chart, 'Statistik', context),
                              fiturCard(Icons.person, 'Profile', context),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Statistik Section
                      sectionTitle('Statistik'),
                      const SizedBox(height: 12),
                      buildStatistikSection(),

                      const SizedBox(height: 20),

                      // Jadwal section
                      sectionTitle('Jadwal'),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('jadwal').orderBy('tanggal').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text('Terjadi error saat mengambil jadwal'),
                            );
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text('Belum ada jadwal'),
                            );
                          }
                          return Column(
                            children: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final tanggal = (data['tanggal'] as Timestamp).toDate();
                              final jam = data['jam'] ?? '';
                              final lokasi = data['lokasi'] ?? '';
                              final status = data['status'] ?? 'belum'; // default 'belum'
                              return JadwalCardInteractive(
                                id: doc.id,
                                title: 'Latihan',
                                date: '${tanggal.day.toString().padLeft(2, '0')} ${_bulanIndo(tanggal.month)}, ${tanggal.year}',
                                time: jam,
                                location: lokasi,
                                status: status,
                              );
                            }).toList(),
                          );
                        },
                      ),

                      // Kurangi tinggi agar tidak overflow
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),

      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            bottomNavItem(Icons.home, 'Home', () {
              // navigasi ke halaman Home
            }),
            bottomNavItem(Icons.group, 'Pemain', () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlayerListPage())
              );
            }),
            bottomNavItem(Icons.format_list_bulleted, 'Line Up', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LineUpPage()),
              );
            }),
            bottomNavItem(Icons.logout, 'Logout', () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => WelcomeScreen()),
              );
            })
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget fiturCard(IconData icon, String label, BuildContext context) {
    return InkWell(
      onTap: () {
        if (label == 'Data Pemain') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerListPage(),
            ),
          );
        }

        // Update Page Profile
        else if (label == 'Profile') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProfilePage(),
            ),
          );
        }

        // Update Aspek Penilaian Page
        else if (label == 'Data Aspek') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AspekPenilaianPage(),
            ),
          );
        }

        // Update Hasil Penilaian Page
        else if (label == 'Penilaian') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HasilPenilaianPage()),
          );
        }

        else if (label == 'Data Kriteria') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DataKriteriaPage()),
          );
        }

        else if (label == 'Statistik') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) =>  StatistikPemainPage()),
          );
        }

        else if (label == 'Atur Jadwal') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) =>  const AturJadwalPage()),
          );
        }

        else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fitur "$label" belum tersedia')),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: SizedBox(
          width: 80,
          child: Column(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(2, 2))
                  ],
                ),
                child: Icon(icon, size: 28),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget bottomNavItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  // buildProfileSection() DIHAPUS

  Widget buildStatistikSection() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 8),
        children: [
          // Total Pemain - real-time dari Firestore
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('players').snapshots(),
            builder: (context, snapshot) {
              int total = 0;
              if (snapshot.hasData) {
                total = snapshot.data!.docs.length;
              }
              return statistikCard('Total Pemain', total.toString());
            },
          ),
          statistikCard('Line Up', '5'),
          // Latihan Selesai dinamis
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jadwal')
                .where('status', isEqualTo: 'selesai')
                .snapshots(),
            builder: (context, snapshot) {
              int selesai = 0;
              if (snapshot.hasData) {
                selesai = snapshot.data!.docs.length;
              }
              return statistikCard('Latihan Selesai', selesai.toString());
            },
          ),
          // Penilaian: jumlah pemain unik yang sudah dinilai
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('penilaian').snapshots(),
            builder: (context, snapshot) {
              int totalPemainDinilai = 0;
              if (snapshot.hasData) {
                final docs = snapshot.data!.docs;
                final pemainSet = <String>{};
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final pemain = data['pemain'];
                  if (pemain != null && pemain.toString().isNotEmpty) {
                    pemainSet.add(pemain.toString());
                  }
                }
                totalPemainDinilai = pemainSet.length;
              }
              return statistikCard('Penilaian', totalPemainDinilai.toString());
            },
          ),
        ],
      ),
    );
  }

  Widget statistikCard(String label, String value) {
    return Container(
      width: 140,
      margin: EdgeInsets.symmetric(horizontal: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }
}

// JadwalCardInteractive: Card Jadwal yang bisa diklik dan ada tombol Latihan Selesai
class JadwalCardInteractive extends StatelessWidget {
  final String id;
  final String title;
  final String date;
  final String time;
  final String location;
  final String status;

  const JadwalCardInteractive({
    Key? key,
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: InkWell(
          onTap: () {
            if (status != 'selesai') {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Latihan Selesai?'),
                  content: Text('Tandai jadwal ini sebagai latihan selesai?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('jadwal')
                            .doc(id)
                            .update({'status': 'selesai'});
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Latihan ditandai selesai!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text('Latihan Selesai'),
                    ),
                  ],
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports, size: 20),
                    SizedBox(width: 8),
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
                    if (status == 'selesai')
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Chip(
                          label: Text('Selesai', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.green,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.calendar_today, size: 16),
                    SizedBox(width: 6),
                    Text('$date\n$time'),
                    Spacer(),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.red,),
                        SizedBox(width: 4),
                        Container(
                          constraints: BoxConstraints(maxWidth: 120),
                          child: Text(
                            _shortenLocation(location),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Carousel Widget
class _DashboardCarousel extends StatefulWidget {
  @override
  State<_DashboardCarousel> createState() => _DashboardCarouselState();
}

class _DashboardCarouselState extends State<_DashboardCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.7, initialPage: 2);
  int _currentPage = 2;

  final List<String> images = [
    'assets/images/singa.png',
    'assets/images/singa.png',
    'assets/images/singa.png',
    'assets/images/singa.png',
    'assets/images/singa.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final isCurrent = index == _currentPage;
              final scale = isCurrent ? 1.0 : 0.8;
              final opacity = isCurrent ? 1.0 : 0.7;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.ease,
                padding: EdgeInsets.symmetric(vertical: isCurrent ? 0 : 16, horizontal: 8),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        images[index],
                        fit: BoxFit.cover,
                        height: 180,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(),
        // Dot indicator (hanya 3 titik)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (dotIndex) {
            bool isActive = _currentPage == dotIndex;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 14 : 8,
              decoration: BoxDecoration(
                color: isActive ? Colors.orange : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }
}