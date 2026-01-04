import 'package:flutter/material.dart';
import 'models/course.dart';
import 'app.dart';
import 'db/course_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final List<Course> coursesList = await loadCourses();

  runApp(UniMateApp(initialCourses: coursesList));
}
