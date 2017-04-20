import "gopkg.in/fatih/set.v0"

func getSubnetDiffRouters(oldsw *subnet.Subnet, newsw *subnet.Subnet) (delRouters []string, addRouters []string){

        allRouters := set.New()
        oldRouters := set.New()
        newRouters := set.New()

        for _, r := range oldsw.Routers {
                oldRouters.Add(r)
        }

        for _, r := range newsw.Routers {
                newRouters.Add(r)
        }

        unionNew := set.Union(allRouters, newRouters)
        unionOld := set.Union(allRouters, oldRouters)

        delRouters = set.StringSlice(set.Difference(oldRouters, unionNew))
        addRouters = set.StringSlice(set.Difference(newRouters, unionOld))
        return delRouters, addRouters
}
