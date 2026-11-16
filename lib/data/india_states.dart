/// All 28 Indian states and 8 union territories, with search aliases and a
/// small set of commonly used city hints. The list is used only for local
/// profile selection; it is not presented as an exhaustive city directory.
class IndiaState {
  final String name;
  final String type;
  final List<String> aliases;
  final List<String> cities;

  const IndiaState({
    required this.name,
    required this.type,
    this.aliases = const [],
    this.cities = const [],
  });

  String get label => name;
}

const indiaStates = <IndiaState>[
  IndiaState(
    name: 'Andhra Pradesh',
    type: 'State',
    aliases: ['AP', 'Andhra'],
    cities: ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Tirupati', 'Nellore'],
  ),
  IndiaState(
    name: 'Arunachal Pradesh',
    type: 'State',
    aliases: ['AR', 'Arunachal'],
    cities: ['Itanagar', 'Naharlagun', 'Pasighat', 'Tawang'],
  ),
  IndiaState(
    name: 'Assam',
    type: 'State',
    aliases: ['AS'],
    cities: ['Guwahati', 'Dibrugarh', 'Silchar', 'Jorhat', 'Tezpur'],
  ),
  IndiaState(
    name: 'Bihar',
    type: 'State',
    aliases: ['BR'],
    cities: ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Darbhanga'],
  ),
  IndiaState(
    name: 'Chhattisgarh',
    type: 'State',
    aliases: ['CG', 'Chhatisgarh'],
    cities: ['Raipur', 'Bilaspur', 'Durg', 'Bhilai', 'Korba'],
  ),
  IndiaState(
    name: 'Goa',
    type: 'State',
    aliases: ['GA'],
    cities: ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa'],
  ),
  IndiaState(
    name: 'Gujarat',
    type: 'State',
    aliases: ['GJ'],
    cities: ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar'],
  ),
  IndiaState(
    name: 'Haryana',
    type: 'State',
    aliases: ['HR'],
    cities: ['Gurugram', 'Faridabad', 'Panipat', 'Ambala', 'Karnal'],
  ),
  IndiaState(
    name: 'Himachal Pradesh',
    type: 'State',
    aliases: ['HP', 'Himachal'],
    cities: ['Shimla', 'Dharamshala', 'Mandi', 'Solan', 'Kullu'],
  ),
  IndiaState(
    name: 'Jharkhand',
    type: 'State',
    aliases: ['JH'],
    cities: ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Hazaribagh'],
  ),
  IndiaState(
    name: 'Karnataka',
    type: 'State',
    aliases: ['KA'],
    cities: ['Bengaluru', 'Mysuru', 'Mangaluru', 'Hubballi', 'Belagavi'],
  ),
  IndiaState(
    name: 'Kerala',
    type: 'State',
    aliases: ['KL'],
    cities: ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kollam'],
  ),
  IndiaState(
    name: 'Madhya Pradesh',
    type: 'State',
    aliases: ['MP'],
    cities: ['Bhopal', 'Indore', 'Gwalior', 'Jabalpur', 'Ujjain'],
  ),
  IndiaState(
    name: 'Maharashtra',
    type: 'State',
    aliases: ['MH'],
    cities: ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad'],
  ),
  IndiaState(
    name: 'Manipur',
    type: 'State',
    aliases: ['MN'],
    cities: ['Imphal', 'Thoubal', 'Churachandpur'],
  ),
  IndiaState(
    name: 'Meghalaya',
    type: 'State',
    aliases: ['ML'],
    cities: ['Shillong', 'Tura', 'Jowai'],
  ),
  IndiaState(
    name: 'Mizoram',
    type: 'State',
    aliases: ['MZ'],
    cities: ['Aizawl', 'Lunglei', 'Champhai'],
  ),
  IndiaState(
    name: 'Nagaland',
    type: 'State',
    aliases: ['NL'],
    cities: ['Kohima', 'Dimapur', 'Mokokchung'],
  ),
  IndiaState(
    name: 'Odisha',
    type: 'State',
    aliases: ['OR', 'Orissa'],
    cities: ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Puri', 'Berhampur'],
  ),
  IndiaState(
    name: 'Punjab',
    type: 'State',
    aliases: ['PB'],
    cities: ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda'],
  ),
  IndiaState(
    name: 'Rajasthan',
    type: 'State',
    aliases: ['RJ'],
    cities: ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer'],
  ),
  IndiaState(
    name: 'Sikkim',
    type: 'State',
    aliases: ['SK'],
    cities: ['Gangtok', 'Namchi', 'Gyalshing'],
  ),
  IndiaState(
    name: 'Tamil Nadu',
    type: 'State',
    aliases: ['TN', 'Tamilnadu'],
    cities: ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem'],
  ),
  IndiaState(
    name: 'Telangana',
    type: 'State',
    aliases: ['TS', 'TG'],
    cities: ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar'],
  ),
  IndiaState(
    name: 'Tripura',
    type: 'State',
    aliases: ['TR'],
    cities: ['Agartala', 'Udaipur', 'Dharmanagar'],
  ),
  IndiaState(
    name: 'Uttar Pradesh',
    type: 'State',
    aliases: ['UP'],
    cities: ['Lucknow', 'Kanpur', 'Varanasi', 'Agra', 'Noida', 'Prayagraj'],
  ),
  IndiaState(
    name: 'Uttarakhand',
    type: 'State',
    aliases: ['UK', 'Uttaranchal'],
    cities: ['Dehradun', 'Haridwar', 'Haldwani', 'Rishikesh', 'Nainital'],
  ),
  IndiaState(
    name: 'West Bengal',
    type: 'State',
    aliases: ['WB', 'Bengal'],
    cities: ['Kolkata', 'Howrah', 'Siliguri', 'Durgapur', 'Asansol'],
  ),
  IndiaState(
    name: 'Andaman and Nicobar Islands',
    type: 'Union territory',
    aliases: ['AN', 'Andaman', 'Nicobar'],
    cities: ['Port Blair'],
  ),
  IndiaState(
    name: 'Chandigarh',
    type: 'Union territory',
    aliases: ['CH'],
    cities: ['Chandigarh'],
  ),
  IndiaState(
    name: 'Dadra and Nagar Haveli and Daman and Diu',
    type: 'Union territory',
    aliases: ['DNHDD', 'Daman', 'Diu', 'Silvassa'],
    cities: ['Silvassa', 'Daman', 'Diu'],
  ),
  IndiaState(
    name: 'Delhi',
    type: 'Union territory',
    aliases: ['DL', 'New Delhi', 'NCR'],
    cities: ['New Delhi', 'Delhi', 'Dwarka', 'Rohini'],
  ),
  IndiaState(
    name: 'Jammu and Kashmir',
    type: 'Union territory',
    aliases: ['JK', 'J & K', 'Kashmir'],
    cities: ['Srinagar', 'Jammu', 'Anantnag', 'Baramulla'],
  ),
  IndiaState(
    name: 'Ladakh',
    type: 'Union territory',
    aliases: ['LA'],
    cities: ['Leh', 'Kargil'],
  ),
  IndiaState(
    name: 'Lakshadweep',
    type: 'Union territory',
    aliases: ['LD'],
    cities: ['Kavaratti'],
  ),
  IndiaState(
    name: 'Puducherry',
    type: 'Union territory',
    aliases: ['PY', 'Pondicherry'],
    cities: ['Puducherry', 'Karaikal', 'Mahe', 'Yanam'],
  ),
];

IndiaState? findIndiaState(String stateName) {
  final normalized = _normalize(stateName);
  if (normalized.isEmpty) return null;
  for (final state in indiaStates) {
    if (_normalize(state.name) == normalized) return state;
    if (state.aliases.any((alias) => _normalize(alias) == normalized)) {
      return state;
    }
  }
  for (final state in indiaStates) {
    if (_normalize(state.name).contains(normalized) ||
        normalized.contains(_normalize(state.name))) {
      return state;
    }
  }
  return null;
}

bool stateMatchesQuery(IndiaState state, String query) {
  final q = _normalize(query);
  if (q.isEmpty) return true;
  return _normalize(state.name).contains(q) ||
      state.type.toLowerCase().contains(q) ||
      state.aliases.any((alias) => _normalize(alias).contains(q)) ||
      state.cities.any((city) => _normalize(city).contains(q));
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll('&', ' and ')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();
