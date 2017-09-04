OBJS = deSubGraphKit.mast deJSONKit.mast makeCycleBreaker.mast notnull.mast makeUncaller.mast DEBuilderOf.mast

test: $(OBJS)
	monte eval uneval.mt

%.mast: %.mt
	@ echo "MONTEC $<"
	@ monte bake $<

