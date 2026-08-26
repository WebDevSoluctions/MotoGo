import 'package:flutter/material.dart';

class DestinationCard extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onDestinationSelected;

  const DestinationCard({
    super.key,
    required this.controller,
    this.onChanged,
    this.onDestinationSelected,
  });

  @override
  State<DestinationCard> createState() =>
      _DestinationCardState();
}

class _DestinationCardState
    extends State<DestinationCard> {
  final List<String> _destinations = [
    'Cuiabá - MT',
    'São João del-Rei - MG',
    'Tiradentes - MG',
    'Barbacena - MG',
    'Barroso - MG',
  ];

  List<String> suggestions = [];

  bool showSuggestions = false;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(
      _handleControllerChange,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(
      _handleControllerChange,
    );

    super.dispose();
  }

  void _handleControllerChange() {
    final text =
        widget.controller.text.trim();

    if (text.isEmpty) {
      if (!mounted) return;

      setState(() {
        suggestions = [];
        showSuggestions = false;
      });

      return;
    }

    final query =
        text.toLowerCase();

    final results =
        _destinations.where(
      (destination) {
        return destination
            .toLowerCase()
            .contains(query);
      },
    ).toList();

    if (!mounted) return;

    setState(() {
      suggestions = results;
      showSuggestions = results.isNotEmpty;
    });

    widget.onChanged?.call(text);
  }

  void _selectDestination(
    String destination,
  ) {
    widget.controller.text =
        destination;

    widget.controller.selection =
        TextSelection.fromPosition(
      TextPosition(
        offset:
            destination.length,
      ),
    );

    setState(() {
      showSuggestions = false;
      suggestions = [];
    });

    widget.onDestinationSelected
        ?.call(destination);

    widget.onChanged?.call(
      destination,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .05,
            ),

            blurRadius: 12,

            offset:
                const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Text(
            'Destino',

            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          TextField(
            controller:
                widget.controller,

            textInputAction:
                TextInputAction.search,

            decoration:
                InputDecoration(
              hintText:
                  'Para onde você vai?',

              prefixIcon:
                  const Icon(
                Icons.location_on,
                color: Colors.red,
              ),

              suffixIcon:
                  widget.controller
                          .text
                          .isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            widget.controller
                                .clear();

                            setState(() {
                              suggestions =
                                  [];
                              showSuggestions =
                                  false;
                            });
                          },

                          icon:
                              const Icon(
                            Icons.close,
                          ),
                        )
                      : null,

              filled: true,

              fillColor:
                  Colors.grey.shade100,

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),

                borderSide:
                    BorderSide.none,
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),

                borderSide:
                    const BorderSide(
                  color:
                      Colors.green,
                  width: 2,
                ),
              ),
            ),
          ),

          // ==================================================
          // SUGESTÕES
          // ==================================================

          if (showSuggestions &&
              suggestions.isNotEmpty)
            Container(
              margin:
                  const EdgeInsets.only(
                top: 10,
              ),

              decoration:
                  BoxDecoration(
                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(
                  16,
                ),

                border:
                    Border.all(
                  color:
                      Colors.grey.shade200,
                ),
              ),

              child: Column(
                children:
                    suggestions.map(
                  (destination) {
                    return InkWell(
                      onTap: () {
                        _selectDestination(
                          destination,
                        );
                      },

                      child: Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),

                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,

                              decoration:
                                  BoxDecoration(
                                color: Colors
                                    .green
                                    .withOpacity(
                                  .10,
                                ),

                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),

                              child:
                                  const Icon(
                                Icons
                                    .location_on_outlined,

                                color:
                                    Colors.green,
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child: Text(
                                destination,

                                style:
                                    const TextStyle(
                                  fontSize:
                                      15,

                                  fontWeight:
                                      FontWeight
                                          .w500,
                                ),
                              ),
                            ),

                            const Icon(
                              Icons
                                  .arrow_forward_ios,
                              size: 15,
                              color:
                                  Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
        ],
      ),
    );
  }
}