multiRF<-function(trees){
  if(class(trees)!="multiPhylo")
    stop("trees should be an object of class \"multiPhylo\"")
  N<-length(trees)
  RF<-matrix(0,N,N)
  if(any(sapply(unclass(trees),is.rooted))){
    cat("Some trees are rooted. Unrooting all trees.\n")
    trees<-lapply(unclass(trees),unroot)
  }
  foo<-function(pp) lapply(pp,function(x,pp)
    sort(attr(pp,"labels")[x]),pp=pp)
  xx<-lapply(unclass(trees),function(x) foo(prop.part(x)))
  for(i in 1:(N-1)) for(j in (i+1):N)
    RF[i,j]<-RF[j,i]<-2*sum(!xx[[i]]%in%xx[[j]])
  RF
}

RFsample_rooted <- function(trees1, trees2){
  RFmatrix <- matrix(nrow=length(trees2), ncol=length(trees1))
  for(i in 1:length(trees1)){
    for(j in 1: length(trees2)){
      RF.dist(trees1[[i]], trees2[[j]], rooted=T) -> RF
      RF -> RFmatrix[j,i]
    }
    info <- sprintf("%d%% done", round((i/100)*100))
  }
  #close(progress)
  RFmatrix
}



RFsample_unrooted <- function(trees1, trees2){
  RFmatrix <- matrix(nrow=length(trees2), ncol=length(trees1))
  for(i in 1:length(trees1)){
    for(j in 1: length(trees2)){
      RF.dist(trees1[[i]], trees2[[j]]) -> RF
      RF -> RFmatrix[j,i]
    }
    info <- sprintf("%d%% done", round((i/100)*100))
  }
  #close(progress)
  RFmatrix
}



