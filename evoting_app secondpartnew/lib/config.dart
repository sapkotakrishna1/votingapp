class Config {
  // Base IP / URL
  static const String baseUrl = "http://192.168.1.101/evoting_api";

  // Endpoints
  //Register page
  static String get ocr => "$baseUrl/ocr.php";
  static String get register => "$baseUrl/register.php";

  //Login page
  static String get login => "$baseUrl/login.php";

  //Home page
  static String get getcandidates => "$baseUrl/getcandidates.php";
  static String get getuserprofile => "$baseUrl/getuserprofile.php";

  //adminhome page
  static String get getusers => "$baseUrl/getusers.php";
  static String get updateuser => "$baseUrl/updateuser.php";
  static String get approveUser => "$baseUrl/approve.php";

  //candidate details screen
  // Admin – delete candidate
  static String deleteCandidate(int id) =>
      "$baseUrl/deletecandidates.php?id=$id";

  static String get editCandidate => "$baseUrl/editcandidate.php";

  //candidate management screen
  static String get getCandidates => "$baseUrl/getcandidates.php";

  static String get addCandidate => "$baseUrl/addcandidates.php";
  static String get editCandidateM => "$baseUrl/editcandidates.php";

  //voting home page
  // Results
  static String get saveResult => "$baseUrl/saveresult.php";

  static String get getElectionResults => "$baseUrl/getElectionResults.php";

  static String get verifypassword => "$baseUrl/verify_password.php";

  static String get verifyFaceUrl => "$baseUrl/verify_face.php";
}
