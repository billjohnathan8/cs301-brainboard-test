.PHONY: inframap inframap-full terraform-graph

inframap:
	$(MAKE) -C ../.. inframap

inframap-full:
	$(MAKE) -C ../.. inframap-full

terraform-graph:
	$(MAKE) -C ../.. terraform-graph
