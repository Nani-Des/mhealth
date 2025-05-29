# TensorFlow Lite (for NLP)
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Hive
-keep class com.hivemq.** { *; }
-dontwarn com.hivemq.**

# Prevent R8 from removing unused classes
-dontoptimize
-dontpreverify