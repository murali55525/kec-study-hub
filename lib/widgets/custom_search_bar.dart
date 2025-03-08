import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_search_delegate.dart';

class CustomSearchBar extends StatefulWidget {
  final String token;
  final String deviceId;

  const CustomSearchBar({super.key, required this.token, required this.deviceId});

  @override
  State<CustomSearchBar> createState() => CustomSearchBarState();
}

class CustomSearchBarState extends State<CustomSearchBar> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search resources...',
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF00246B)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear, color: Color(0xFF00246B)),
          onPressed: () => _searchController.clear(),
        ),
      ),
      onSubmitted: (value) {
        if (value.isNotEmpty) {
          showSearch(context: context, delegate: CustomSearchDelegate(deviceId: widget.deviceId, token: widget.token, initialQuery: value));
        }
      },
    );
  }
}