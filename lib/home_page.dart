import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

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
          : const Center(child: CircularProgressIndicator()),
    );
  }

//Kod Parçalama
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
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
          const SizedBox(height: 16),
          _buildConclusionText(),
          const SizedBox(height: 16),
          _buildDividingLine(),
          const SizedBox(height: 16),
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
      style: const TextStyle(fontSize: 24),
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
        const SizedBox(width: 16),
        //İstediğimiz kuru seçmek için;
        //Kur değerler olduğu için string olacak
        _buildCureDropDown(),
      ],
    );
  }

  Widget _buildCureDropDown() {
    return DropdownButton<String>(
      value: _selectedExchangeRate,
      icon: const Icon(Icons.arrow_downward),
      //usd altındaki çizgiyi kaldırma işlemi
      underline: const SizedBox(),
      items: _odds.keys.map((String cure) {
        return DropdownMenuItem<String>(
          value: cure,
          child: Text(cure),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedExchangeRate = newValue;
            _calculate();
          });
        }
      },
    );
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

  Widget _buildListItem(BuildContext context, int index) {
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
    try {
      await _fetchFromTcmbApi();
      if (_odds.isNotEmpty) {
        print('TCMB API verisi alındı: $_odds');
      } else {
        print('TCMB API verisi boş, mevcut API’ye geçiliyor.');
        await _fetchFromExistingApi();
      }
    } catch (e) {
      print('TCMB API başarısız oldu: $e');
      await _fetchFromExistingApi();
    }
  }

  Future<void> _fetchFromTcmbApi() async {
    //Verileri internetten çekerken bekleme

    await Future.delayed(const Duration(seconds: 2));

    final response =
        await http.get(Uri.parse('https://www.tcmb.gov.tr/kurlar/today.xml'));
    if (response.statusCode == 200) {
      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('Currency');

      _odds.clear();
      for (var item in items) {
        final currencyCode = item.getElement('CurrencyCode')?.text;
        final forexSelling = item.getElement('ForexSelling')?.text;

        if (currencyCode != null && forexSelling != null) {
          double? sellingRate =
              double.tryParse(forexSelling.replaceAll(',', '.'));
          if (sellingRate != null) {
            _odds[currencyCode] = sellingRate;
          }
        }
      }

      if (_odds.isNotEmpty) {
        _selectedExchangeRate = _odds.keys.first;
      }
      setState(() {});
    } else {
      print('TCMB API çağrısında hata: ${response.statusCode}');
      throw Exception('TCMB API hata: ${response.statusCode}');
    }
  }

  Future<void> _fetchFromExistingApi() async {
    await Future.delayed(const Duration(seconds: 2));
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
    if (response.statusCode == 200) {
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
    } else {
      print('Mevcut API çağrısında hata: ${response.statusCode}');
    }
  }
}
