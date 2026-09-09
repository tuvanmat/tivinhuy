import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tv_flutter_app/controllers/movies_controller.dart';
import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/pages/movie_detail_screen.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/utils/labels.dart';
import 'package:tv_flutter_app/utils/navigation.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final MoviesController _moviesController = MoviesController();

  List<MovieModel> _searchResults = [];
  bool _isLoading = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activateSearchField();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // CHỈ FOCUS Ô NHẬP LIỆU TRÊN TV, KHÔNG GỌI BÀN PHÍM ẢO HỆ THỐNG GÂY CRASH
  Future<void> _activateSearchField() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _textFieldFocusNode.requestFocus();
  }

  Future<void> _closeSearchPage() async {
    if (_isClosing) return;
    _isClosing = true;

    _textFieldFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    if (mounted) {
      final buttonFocusProvider = Provider.of<ButtonFocusProvider>(
        context,
        listen: false,
      );
      buttonFocusProvider.buttonFocusedLabel = "${topMoviesItem}0";
      buttonFocusProvider.lastButtonFocusedLabel = "${topMoviesItem}0";
    }

    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Future<void> _performSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;

    _textFieldFocusNode.unfocus();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _moviesController.searchMovies(keyword);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          _closeSearchPage();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TIÊU ĐỀ
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        _closeSearchPage();
                      },
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Tìm kiếm phim',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Ô TÌM KIẾM (Đã loại bỏ gọi SystemChannels gây lỗi)
                TextField(
                  controller: _searchController,
                  focusNode: _textFieldFocusNode,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nhập tên phim cần tìm...',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.grey[900],
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white70,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                  ),
                  onTap: () {
                    _activateSearchField();
                  },
                  onSubmitted: (value) {
                    _performSearch(value);
                  },
                ),
                const SizedBox(height: 20),

                // KẾT QUẢ
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.red,
                          ),
                        )
                      : _searchResults.isEmpty
                          ? const Center(
                              child: Text(
                                'Chưa có kết quả tìm kiếm.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final movie = _searchResults[index];
                                return _SearchItemTile(
                                  movie: movie,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ITEM PHIM
class _SearchItemTile extends StatefulWidget {
  final MovieModel movie;

  const _SearchItemTile({
    required this.movie,
  });

  @override
  State<_SearchItemTile> createState() => _SearchItemTileState();
}

class _SearchItemTileState extends State<_SearchItemTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!mounted) return;
        setState(() {
          _hasFocus = hasFocus;
        });
      },
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            materialNavigationRoute(
              context,
              MovieDetailScreen(
                slug: widget.movie.slug,
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(
            vertical: 6,
          ),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hasFocus
                ? Colors.red.withValues(alpha: 0.3)
                : Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasFocus ? Colors.red : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Image.network(
                widget.movie.verticalPhoto,
                width: 50,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.movie,
                    color: Colors.grey,
                  );
                },
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.movie.slug,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
