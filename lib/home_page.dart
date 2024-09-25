import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //Hiç bir zaman değişmeyeceği için final yapılabilir.
  final String _apiKey = "7a84f505485039fdc11e055a004986e0";

  final String _baseUrl =
      "http://api.exchangeratesapi.io/v1/latest?access_key=";

  TextEditingController _controller = TextEditingController();

  Map<String, double> _odds = {};

  String _selectedExchangeRate = "USD";
  double _conclusion = 0;

  //Biz bunu uygulama açıldığında çağırmak istediğim için
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pullDataFromInternet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //Appbar widget kısmında hata verir bu sebeple aşağıda appBar döndürdüğü yazılır.
      appBar: _buildAppBar(),
      //Eğer oranlar boş değilse _buildBody() fonksiyonunu getir ama eğer boşsa yüklenme efektini getir.
      body: _odds.isNotEmpty
          ? _buildBody()
          : Center(child: CircularProgressIndicator()),
    );
  }

//Kod Parçalama
  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        "Kur Dönüştürücü",
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.lime,
    );
  }

  Widget _buildBody() {
    //Return widget döndürmemiz gerektiği için
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildExchangeRow(),
          SizedBox(
            height: 16,
          ),
          _buildConclusionText(),
          SizedBox(
            height: 16,
          ),
          _buildDividingLine(),
          SizedBox(
            height: 16,
          ),
          //Listviewıda row içine öylece koyarsak hata alırız bunuda expanded ile sarmalıyız.
          //Kurların listelendiği alan
          _buildCureList(),
        ],
      ),
    );
  }

  Widget _buildConclusionText() {
    return Text(
      "${_conclusion.toStringAsFixed(2)} ₺",
      style: TextStyle(fontSize: 24),
    );
  }

  Widget _buildDividingLine() {
    return Container(
      color: Colors.black,
      height: 2,
    );
  }

  Widget _buildExchangeRow() {
    return Row(
      //Row içerisinde expanded ile sarmadan textfieldı kullanamayız.
      children: [
        _buildCureTextField(),
        SizedBox(
          width: 16,
        ),
        //İstediğimiz kuru seçmek için;
        //Kur değerler olduğu için string olacak
        _buildCureDropDown(),
      ],
    );
  }

  Widget _buildCureDropDown() {
    return DropdownButton<String>(
        value: _selectedExchangeRate,
        icon: Icon(Icons.arrow_downward),
        //usd altındaki çizgiyi kaldırma işlemi
        underline: SizedBox(),
        items: _odds.keys.map((String cure) {
          return DropdownMenuItem<String>(
            value: cure,
            child: Text(cure),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            _selectedExchangeRate = newValue;
            _calculate();
          }
        });
  }

  Widget _buildCureTextField() {
    return Expanded(
      child: TextField(
        controller: _controller,
        //Klavye değişimi;
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (String newValue) {
          //Kendi içerisinde setstate barındırdığı için burada setstate içerisinde yazmadık.
          _calculate();
        },
      ),
    );
  }

  Widget _buildCureList() {
    return Expanded(
      child: ListView.builder(
        itemBuilder: _buildListItem,
        itemCount: _odds.keys.length,
      ),
    );
  }

  Widget? _buildListItem(BuildContext context, int index) {
    return ListTile(
      title: Text(_odds.keys.toList()[index]),
      trailing: Text("${_odds.values.toList()[index].toStringAsFixed(2)} ₺"),
    );
  }

  //TextFielda yazılan her değerde hesaplama işlemi için fonksiyon oluşturuyorum.
  void _calculate() {
    //Double çevirmeyi dene double çevrilemeyecek birşeyse null yap
    double? value = double.tryParse(_controller.text);
    double? odd = _odds[_selectedExchangeRate];

    if (value != null && odd != null) {
      setState(() {
        _conclusion = value * odd;
      });
    }
  }

  void _pullDataFromInternet() async {
    //Verileri internetten çekerken bekleme
    await Future.delayed(Duration(seconds: 2));
    //Uri dartcore ait bir sınıftır.
    Uri uri = Uri.parse(_baseUrl + _apiKey);
    //Get veri çekerken kullanılır.
    //Post veri eklerken kullanılır.
    //Put genellikle güncelleme yaparken kullanılır.
    //Delete silme yaparken kullanılır.
    //Bunlar birazda backend alanındaki arkadaşa bağlıdır. Arkadaş silme işleminide post ile yapmamızı isteyebilir.
    //Çekilen veri response nesnesinde tutulur.
    http.Response response = await http.get(uri);

    //Bize gelecek veri json formatında geleceği için dönüştürme yapıyoruz.
    Map<String, dynamic> parsedResponse = jsonDecode(response.body);
    //Daha sonrasında altta yorum satırında yazdığımız verileri burada yazıyoruz.
    Map<String, dynamic> rates = parsedResponse["rates"];
    //Türk Lirasının karşılığı
    //Mapin için ona karşılık gelen anahtarın olup olmadığına emin olamadığımız için null
    double? baseTlCure = rates["TRY"];

    //Null olup olmadığı kontrolü
    if (baseTlCure != null) {
      //Eğer null değilse tek tek kurları dolaş
      for (String countryCure in rates.keys) {
        //Dartta int double doğrudan dönüştürülemiyor.
        double? baseCure = double.tryParse(rates[countryCure].toString());
        //Json eur endeksli geldiği için;
        if (baseCure != null) {
          double tlCure = baseTlCure / baseCure;
          _odds[countryCure] = tlCure;
        }
      }
    }
    //Bütün bu döngü bittiğinde setState yapıyoruz.
    setState(() {});
  }
}
