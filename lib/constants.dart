
import 'package:flutter/material.dart';

late double width;
late double height;

Color white = const Color(0xffffffff);
Color primary = const Color(0xFF0B3089);
Color tabLight = const Color(0xffFAFAFA);
Color red = const Color(0xffF53939);
Color green = const Color(0xff1EDB53);
Color black = const Color(0xff000000);
Color yellow = const Color(0xffFFC10A);
Color pink = const Color(0xffFF7B92);
Color grey = const Color(0xffD9D9D9);
Color sectionColor = const Color(0xffF5F7F9);

Color chatBlue = const Color(0xff0076F7);
Color chatRed = const Color(0xffFF1AA3);
Color chatGrey = const Color(0xffF2F4F5);
Color textGreyColor = const Color(0xff9BA1A9);
Color chatTimeColor = const Color(0xffA7A4A4);
Color appointmentTimeColor = const Color(0xffA7A5A5);
Color dividerColor = const Color(0xff929292);
Color ratingTextColor = const Color(0xff666060);
Color semiGrey = const Color(0xff808080);
Color complementaryRed = const Color(0xffBD3A32);

double screenWidth = width / 390;
double screenHeight = height / 844;

const bool status = true;
bool call = true;

bool aboutSelected = true;
bool reviewsSelected = false;
bool portfolioSelected = false;

late bool isTabSelected;
List<String> servicesList = [
  'Painting',
  'Electrical Repairs',
  'Grass Cutting',
  'Painting',
  'Electrical Repairs',
  'Grass Cutting'
];

List<String> ratingNames = ['Khufra', 'Eben', 'Clay'];
List<String> ratingTimePosted = ['Just now', '2 days ago', '1 week ago'];
List<String> ratingComment = [
  'Professional and hard-working painter. 👌',
  'Neat work done. Highly recommended. 👍',
  'Man used emulsion paint when I said I want oil paint. Bad choice.💩🚮'
];
List<bool> isCommentLiked = [true, false, true];

List<double> ratingsWidth = [];

List jobStatusOptions = [
  false,
  true,
  true,
  false,
  false,
  false,
  true,
  true,
  true
];

late int starsGiven;
bool isGridViewSelected = true;
bool isSingleViewSelected = false;
List ratingStars = [4, 5, 1];

List<String> daysList = ['Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat', 'Sun'];
List<String> dateList = ['11', '12', '13', '14', '15', '16', '17'];
List<String> timeList = [
  '8:00 AM',
  '10:00 AM',
  '12:30 PM',
  '3:00 PM',
  '5:00 PM'
];
bool isAddressBarClicked = false;
bool isDashboardTabSelected = false;
bool isSummaryClicked = false;

List<String> addressTypesDD = [
  'Home',
  'Office',
  'Hotel / Hostel',
  'Warehouse',
];

List<String> dashBoardTabList = [
  'All',
];

final serviceCategoryList = [
  'Appliance Repairers',
  'Electricians',
  ' Plumbers',
  'Painters',
  'Gardeners & Landscapers',
  'Locksmiths',
  'HVAC Technicians',
  'Tilers',


];
List selectedServiceProvList = [];
List selectedCertList = [];
List selectedExperienceList = [];

List uploadCertList = [];
List uploadExperienceList = [];
List uploadReferenceList = [];
List uploadPortfolioList = [];

//to be deleted
final servicesProvidedList = [
  'Rice cooker and Stove Repairs',
  ' Refirigerator and Fan Repairs',
  ' Laptop Repairs',
  'Mobile Phone Repairs',
  'Electrical Wiring and Rewiring',
  'Meter Repairs and Maintenance',
  'Electrical Panel Upgrades',
  'Pipe Repairs and Installation',
  'Toilet and faucet Repairs',
  'Commercial Plumbing',
  'House/Room Painting',
  'Wallpaper Installations and removal',
  'Furniture Painting',
  'Lawn Mowing and Maintenance',
  'Tree and shrub pruning',
  'Planting and Gardening',
  'Lock installation and repair',
  'Key Cutting and Duplication',
  'Master Key System Installation',
  'Air Conditioning and Heating system Installation',
  'HVAC Maintenance and Repairs',
  'Duct Cleaning and Repairs',
  'Floor/Wall Tiling',
  'Shower/Bathtub Tiling',
  'Tiling Repair and Replacement',

];

final expertiseList = [
  'N/A',
  'Beginner (0 - 1 year)',
  'Amateur (1 - 3 years)',
  'Professional (3 - 6 years)',
  'Expert (6+ years)',
];
List selectedExpertiseList = [];

final momoListOptions = [
  'N/A',
  'MTN Mobile Money',
  'Vodafone Cash',
  'Airtel/Tigo Money',
];

final userRoleList = [
  'Regular Customer',
  'Professional Handyman',
];
List<String> selectedMomoOptions = [];
List<String> selectedMomoOptionsIcons = [
  'assets/icons/mtn_momo.png',
  'assets/icons/vodafone_cash.png',
  'assets/icons/airtel_tigo.png',
];

final chargePerList = ['N/A', 'Hour', '6 hours', '12 hours', 'Day'];
final regionsList = [
  'N/A',
  'Volta Region',
  'Greater Accra Region',
  'Central Region',
  'Western Region',
  'Eastern Region',
  'Savanna Region',
  'Ashanti Region',
  'Northern Region',
  'Upper-West Region',
  'North-East Region',
  'Bono-East Region',
  'Brong Ahafo Region',
  'Ahafo Region',
  'Oti Region',
  'Upper-East Region',
];

final creditCardList = [
  'N/A',
  'MasterCard',
  'Visa Card',
  'American Express',
  'Discover Card',
];

final bankList = [
  'N/A',
  'GCB',
  'Zenith Bank',
  'Standard Chartered',
  'ADB Bank',
];

String dropdownvalue = 'N/A';
String addressValue = 'Home';
String roleValue = 'Regular Customer';
List selectedServiceCatList = [];
String jobApplicationNote = '';

bool referenceLinkError = false;

int priceIndex = 0;

late String regionValue;

List addressStreetName = [];
List addressTownName = [];
List addressRegionName = [];
List addressHouseNum = [];
List categoryList = [];
List categoryServicesList = [];
List certificationList = [];
List experienceList = [];

bool isJobAboutClicked = true;
bool isJobPortfolioClicked = false;

String chargeRateSelected = 'N/A';
String expertiseSelected = 'N/A';
String roleSelected = '';

bool isJobUpcomingClicked = true;
bool isJobOffersClicked = false;
bool isJobCompletedClicked = false;

int selectedJob = 3;

final upcomingOrderStatusList = [
  'View Order',
  'Ongoing',
  'View Order',
  'View Order',
];
final upcomingNameList = [
  'Leo Messi',
  'Erling Halaand',
  'Cristiano Ronaldo',
  'Walter White'
];
final upcomingDateList = [
  '11-01-2023',
  '04-01-2023',
  '23-05-2023',
  '30-01-2023',
];
final upcomingTimeList = [
  '12:30 AM',
  '03:10 PM',
  '10:30 AM,',
  '05:00 PM',
];
final upcomingImageLocation = [
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
];
final upcomingServices = [
  'Painting',
  'Electrical Repair',
  'Building Renovation',
  'Furniture Painting',
];

final offerOrderStatusList = [
  'View Offer',
  'View Offer',
  'View Offer',
  'View Offer',
];
final offerNameList = [
  'Leo Messi',
  'Erling Halaand',
  'Cristiano Ronaldo',
  'Walter White'
];
final offerDateList = [
  '11-01-2023',
  '04-01-2023',
  '23-05-2023',
  '30-01-2023',
];
final offerTimeList = [
  '12:30 AM',
  '03:10 PM',
  '10:30 AM,',
  '05:00 PM',
];
final offerImageLocation = [
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
];
final offerServices = [
  'Painting',
  'Electrical Repair',
  'Building Renovation',
  'Furniture Painting',
];

final completedOrderStatusList = [
  'Cancelled',
  'Complete',
  'Cancelled',
  'Cancelled',
];
final completedNameList = [
  'Leo Messi',
  'Erling Halaand',
  'Cristiano Ronaldo',
  'Walter White'
];
final completedDateList = [
  '11-01-2023',
  '04-01-2023',
  '23-05-2023',
  '30-01-2023',
];
final completedTimeList = [
  '12:30 AM',
  '03:10 PM',
  '10:30 AM,',
  '05:00 PM',
];
final completedImageLocation = [
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
];
final completedServices = [
  'Painting',
  'Electrical Repair',
  'Building Renovation',
  'Furniture Painting',
];

bool isJobOfferScreen = false;
bool isRememberMeClicked = false;
bool isTermsAndCondAgreed = false;

List<String> generalSectionList = [
  'Account Information',
  'Address Information',
  'Payment Information',
  'Appearance',
  'Notification',
];

List<String> generalSectionIcons = [
  'user_icon',
  'location_icon',
  'wallet_icon',
  'settings_icon',
  'notification_icon',
];

List<String> supportSectionList = [
  'Change Language',
  'Report on Issue',
  'FAQ',
];

List<String> supportSectionIcons = [
  'world_icon',
  'danger_icon',
  'help_icon',
];

List<String> customerFavouritesImageList = [];
List<String> customerFavouritesIDList = [];
List<String> customerFavouritesNameList = [];
List<String> customerFavouritesChargeList = [];
List<String> customerFavouritesChargeRateList = [];
List<String> customerFavouritesRatingList = [];
List<String> customerFavouritesJobTypeList = [];
//-----------------------------------------------------------
List<String> handymanFavouritesImageList = [];
List<String> handymanFavouritesIDList = [];
List<String> handymanFavouritesNameList = [];
List<String> handymanFavouritesChargeList = [];
List<String> handymanFavouritesChargeRateList = [];
List<bool> handymanFavouritesStatusList = [];
List<String> handymanFavouritesJobTypeList = [];

late int handymanSelectedIndex;
late int jobSelectedIndex;

List<String> handymanDashboardJobType = [];
String jobItemID = '';

List<String> handymanDashboardImage = [];

List<String> handymanDashboardName = [];
List<String> handymanDashboardID = [];

List<String> handymanDashboardPrice = [];

List<String> handymanDashboardChargeRate = [];

List<String> handymanDashboardRating = [];

//------------------------------------------------

List<String> jobDashboardJobType = [];

List<String> jobDashboardImage = [];

List<String> jobDashboardName = [];
List<String> jobDashboardID = [];

List<String> jobDashboardPrice = [];

List<String> jobDashboardChargeRate = [];

//------------------------------------------

List<String> cardLogo = [
  'assets/icons/visa_logo.png',
  'assets/icons/visa_logo.png',
  'assets/icons/visa_logo.png',
  'assets/icons/visa_logo.png',
  'assets/icons/visa_logo.png',
];

List<String> cardName = [
  'PJ Agrolics',
  'PJ Agrolics',
  'PJ Agrolics',
];

List<String> cardNumber = [
  '**** **** **** 4765',
  '**** **** **** 4765',
  '**** **** **** 4765',
];

List<String> cardExpiryDate = [
  '**/**',
  '**/**',
  '**/**',
];

List<String> historyPicList = [
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
];

List<String> historyNameList = [
  'Harry Garret',
  'Harry Garret',
  'Harry Garret',
  'Harry Garret',
  'Harry Garret',
];

List<String> historyJobTypeList = [
  'Plumbing',
  'Plumbing',
  'Plumbing',
  'Plumbing',
  'Plumbing',
];

List<String> historyDateList = [
  '22-10-23 || 09:30 PM',
  '22-10-23 || 09:30 PM',
  '22-10-23 || 09:30 PM',
  '22-10-23 || 09:30 PM',
  '22-10-23 || 09:30 PM',
];

List<String> historyPriceList = [
  '15',
  '15',
  '15',
  '15',
  '15',
];

bool loginTextFieldError = false;
bool forgotPasswordEmailError = false;
bool registerFirstNameError = false;
bool registerLastNameError = false;
bool registerEmailError = false;
bool registerPasswordError = false;
bool registerNumberError = false;

int activeIndex = 0;

bool isPersonalInfoReadOnly = true;
bool isPaymentInfoReadOnly = true;
bool isLocationReadOnly = true;
bool isServiceInfoReadOnly = true;
bool isWorkExpReadOnly = true;

String? cardNumberHintText = '';
String? expiryDateHintText = '';
String? cvvHintText = '';
String? payPalHintText = '';
String? chargeHintText = '';
String? chargeRateHintText = 'N/A';
String? expertiseHintText = 'N/A';
String seenByHintText = 'All';
String? ratingHintText = '';
String? jobTotalHintText = 0.toString();

String loggedInUserId = '';
String imageUrl = '';

List experienceFileNames = [];
List certificationFileNames = [];
List referencesList = [];

List<String> addressOptions = [
  'Home',
  'Hotel',
  'Office',
  'Hostel',
];

String apppointmentTown = '';
String apppointmentStreet = '';
String apppointmentRegion = '';
String apppointmentHouseNum = '';

String uploadTown = '';
String uploadStreet = '';
String uploadRegion = '';
String uploadHouseNum = '';

String uploadHandymanTown = '';
String uploadHandymanStreet = '';
String uploadHandymanRegion = '';
String uploadHandymanHouseNum = '';

List<String> addedNote = [];

String fileNameStore = '';


String chargePHint = 'N/A';
String expertHint = 'N/A';

String handymanServiceCatHintText = 'Appliance Repairers';
String handymanServiceProvHintText = 'Refirigirator and Fan Repairs';
String handymanChargePHint = 'N/A';
String handymanExpertHint = 'N/A';

List<String> seenByList = [
  'All',
  'Specific Category',
];

bool jobUploadReadOnly = false;
bool isJobUploadEditReadOnly = true;
bool jobStatus = true;

const int peopleApplied = 0;

String deadline = '';

String deadlineDay = 'Day';
String deadlineMonth = 'Month';
String deadlineYear = 'Year';


List<String> jobPortfolioUrls = [];
List<String> uploadListName = [];
List<String> uploadListTime = [];
List<String> uploadListCategory = [];
List<String> uploadListDate = [];
List<String> uploadListJobStatus = [];
List<String> uploadListImageUrl = [
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
  'assets/images/profile_pic.jpeg',
];

late String selectedJobId;
late String selectedJobType;

String typeClicked = 'Customer';
String currentJobClickedUserId = '';
int selectedJobUploadIndex = 0;

List<String> jobApplicationLinks = [];

String jobApplicationTime = '';
