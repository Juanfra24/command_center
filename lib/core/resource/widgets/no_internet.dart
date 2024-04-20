import 'package:flutter/material.dart';

class NoInternet extends StatelessWidget {
  const NoInternet({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Please check your internet connection!',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          ],
        ),
      ),
    );
  }
}
