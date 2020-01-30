/*****************************************************************************
 *
 * DATA
 * 
 *****************************************************************************/

// Points
int     n       = ...;
range   Points  = 1..n;

// Edges -- sparse set
tuple       edge        {int i; int j;}
setof(edge) Edges       = {<i,j> | ordered i,j in Points};
float         dist[Edges] = ...;

// Decision variables
dvar boolean x[Edges];

tuple Subtour { int size; int subtour[Points]; }
{Subtour} subtours = ...;



/*****************************************************************************
 *
 * MODEL
 * 
 *****************************************************************************/

// Objective
minimize sum (<i,j> in Edges) dist[<i,j>]*x[<i,j>];
subject to {
   
   // Each point is linked with two other points
   forall (j in Points){
      sum (<i,j> in Edges) x[<i,j>] + sum (<j,k> in Edges) x[<j,k>] == 2;
  }        
   // Subtour elimination constraints.
   forall (s in subtours)
       sum (i in Points : s.subtour[i] != 0)
          x[<minl(i, s.subtour[i]), maxl(i, s.subtour[i])>]
           <= s.size-1;
          
};

// POST-PROCESSING to find the subtours

// Solution information
int thisSubtour[Points];
int newSubtourSize;
int newSubtour[Points];

// Auxiliary information
int visited[i in Points] = 0;
setof(int) adj[j in Points] = {i | <i,j> in Edges : x[<i,j>] == 1} union
                              {k | <j,k> in Edges : x[<j,k>] == 1};
execute {

  newSubtourSize = n;
  var printed = 0;
  for (var i in Points) { // Find an unexplored node
    if (visited[i]==1) continue;
    var start = i;
    var node = i;
    var thisSubtourSize = 0;
    for (var j in Points)
      thisSubtour[j] = 0;
    while (node!=start || thisSubtourSize==0) {
      write(i, " -> ");
      ++printed;
      if(printed % 10 == 0){
        writeln("");
      }
      visited[node] = 1;
      var succ = start; 
      for (i in adj[node]) 
        if (visited[i] == 0) {
          succ = i;
          break;
        }
                        
      thisSubtour[node] = succ;
      node = succ;
      ++thisSubtourSize;
    }
	write(start);
    writeln("\nFound subtour of size : ", thisSubtourSize);
    if (thisSubtourSize < newSubtourSize) {
      for (i in Points)
        newSubtour[i] = thisSubtour[i];
        newSubtourSize = thisSubtourSize;
    }
  }
  if (newSubtourSize != n)
    writeln("Best subtour of size ", newSubtourSize);
}



/*****************************************************************************
 *
 * SCRIPT
 * 
 *****************************************************************************/

main {
    var opl = thisOplModel
    var mod = opl.modelDefinition;
    var dat = opl.dataElements;

    var status = 0;
    var it =0;
    while (1) {
        var cplex1 = new IloCplex();
        opl = new IloOplModel(mod,cplex1);
        opl.addDataSource(dat);
        opl.generate();
        it++;
        writeln("Iteration ",it, " with ", opl.subtours.size, " subtours.");
        if (!cplex1.solve()) {
            writeln("ERROR: could not solve");
            status = 1;
            opl.end();
            break;
        }
        opl.postProcess();
        writeln("Current solution : ", cplex1.getObjValue());

        if (opl.newSubtourSize == opl.n) {
          opl.end();
          cplex1.end();
          break; // not found
        }
        dat.subtours.add(opl.newSubtourSize, opl.newSubtour);
    opl.end();
    cplex1.end();
    }

    status;
}