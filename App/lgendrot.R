

cat("The original version of the script:
    http://rpubs.com/lgendrot/sentiment\n\n")
cat("Methods in this file can be compared 
    to get an impression of the changed 
    code, compared to the original.")


###########################################
#             Helper Functions            #
###########################################

# Convert reviews to cleaned list of tokens (words)
convert <- function(documents) {
  tokens <- tokenize(documents)
  my_features <- get_feature_vectors(tokens)
  if ("sentiment" %in% colnames(documents))
    my_features <- prepare(my_features, documents)
  return (my_features)
}

# Prepare features by adding sentiment
prepare <- function(my_features, documents) {
  my_features <- add_targets(my_features, documents) 
  my_features$sentiment <- as.factor(my_features$sentiment) 
  return (my_features)
}

# Display results
results <- function(prediction, reality) {
  
  message("TRUE POSITIVES")
  t <- table(prediction, reality)
  tp <- t[2,2]
  fp <- t[2,1]
  tn <- t[1,1]
  fn <- t[1,2]
  cat(paste("TN:", tn, "FN:", fn, "\n"))
  cat(paste("FP:", fp, "TP:", tp))
  
  message("AMOUNT OF CORRECT PREDICTIONS")
  cat(paste("Correct:", (tp + tn), "/ Incorrect:", (fp + fn)))
  message("ACCURACY")
  cat((tp + tn) / (fp + fn + tp + tn))
  message("TRUE POSITIVE RATE (SENSITIVITY)")
  cat(tp / (tp + fn))
  message("FALSE POSITIVE RATE (FALL-OUT)")
  cat(fp / (fp + tn))
}

###########################################
#            Lgendrot Functions           #
###########################################

# Convert reviews to cleaned list of tokens (words)
# @return "list"
tokenize <- function(document) {
  # Lowercase all words for convenience
  doc <- tolower(document$review)
  # Remove all #hashtags and @mentions
  doc <- gsub("(?:#|@)[a-zA-Z0-9_]+ ?", "", doc)
  # Remove words with more than 3 numbers in them (they overwhelm the corpus, and are uninformative)
  doc <- gsub("[a-zA-Z]*([0-9]{3,})[a-zA-Z0-9]* ?", "", doc)
  # Remove all punctuation
  doc <- gsub("[[:punct:]]", " ", doc)
  # Remove all words shorter than three characters
  doc <- gsub("*\\b[[:alpha:]]{1,2}\\b*", "", doc)
  # Remove all newline characters
  doc <- gsub("[\r\n]", "", doc)
  # Regex pattern for removing stop words
  stop_pattern <- paste0("\\b(", paste0(stopwords("en"), collapse="|"), ")\\b")
  doc <- gsub(stop_pattern, "", doc)
  # Replace whitespace longer than 1 space with a single space
  doc <- gsub(" {2,}", " ", doc)
  # Split on spaces and return list of character vectors
  doc_words <- strsplit(doc, " ")
  return(doc_words)
}


corpus_freq <- function(tokens, corpus_size=NULL, word_list = NULL){
  # Concatenate all tokenized words into a single character list
  all_words <- do.call(c, tokens)
  
  #If corpus size is not blank, and word list is, create a word frequency frame
  #take the top occuring words up to the length of corpus_size
  #and reorder alphabetically
  
  #This gives us an data frame of the most frequent words in our corpus, ordered alphabetically
  #sized by the corpus_size parameter
  if(is.null(word_list) & !is.null(corpus_size)){
    corpusfreq <- data.frame(table(all_words))
    names(corpusfreq) <- c("Word", "Freq")
    corpusfreq$Word <- as.character(corpusfreq$Word)
    corpusfreq$Freq <- as.numeric(corpusfreq$Freq)
    corpusfreq <- corpusfreq[order(-corpusfreq$Freq), ]
    corpusfreq <- corpusfreq[1:corpus_size, ]
    corpusfreq <- corpusfreq[order(corpusfreq$Word), ]
  }
  #Else it is assumed a pre-compiled word list has been passed into the function
  corpusfreq <- data.frame(word_list)
  names(corpusfreq) <- c("Word")
  
  # N docs is where we will store the document frequency (I.E how many documents a word appears in)
  # We'll need this to calculate TF-IDF
  corpusfreq$n_docs <- 0
  
  # For every vector of words in our tokenized list, count how many times each word in our corpus occurs
  for(token_list in tokens){
    t <- data.frame(table(token_list))
    names(t) <- c("Word", "n_docs")
    t$n_docs <- 1
    t_freq <- merge(x=corpusfreq, y=t, by="Word", all.x=TRUE)
    t_freq$n_docs.y[is.na(t_freq$n_docs.y)] <- 0
    corpusfreq$n_docs <- corpusfreq$n_docs + t_freq$n_docs.y
  }
  return(corpusfreq)
}


tfidf <- function(document, corpus){
  #Create a data frame out of a single document and its word frequency
  # For tweets this will be mostly 1's
  doc_f <- data.frame(unlist(table(document)))
  names(doc_f) <- c("Word", "Freq")
  
  #Get a data frame of the words in the corpus found in the current document
  in_doc <- intersect(doc_f$Word, corpus$Word)
  not_in_doc <- data.frame(Word=corpus[!corpus$Word %in% doc_f$Word, ]$Word)
  doc_f <- doc_f[doc_f$Word %in% in_doc, ]
  
  #Get a data frame of the words in the corpus not found in the current document
  #Set their frequency to 0
  # not_in_doc <- data.frame(Word=setdiff(corpus$Word, document))
  not_in_doc$Freq <- 0
  
  #Bind our two data frames, we now have frequencies for the words that are in our corpus, and 0s everywhere else
  tf <- rbind.data.frame(doc_f, not_in_doc)
  tf$Word <- as.character(tf$Word)
  tf$Freq <- as.numeric(tf$Freq)
  
  #Order alphabetically again so it remains compatible with our corpus data frame
  tf <- tf[order(tf$Word), ]
  
  #Calculate the tfidf
  #log1p is the same as log(1+___)
  log_freq <- log1p(tf$Freq)
  log_doc_freq <- log1p(nrow(corpus)/corpus$n_docs)
  log_doc_freq[which(!is.finite(log_doc_freq))] <- 0
  if(length(log_freq) != length(log_doc_freq)) browser()
  if(length(log_freq) != length(log_doc_freq)) return (NULL)
  tf$tfidf <- log_freq * log_doc_freq
  
  #Divide by zero errors get NA values, but should be 0s
  tf$tfidf[is.na(tf$tfidf)] <- 0
  return(tf)
}


# This function takes a token_list (the output of tokenize) and either a corpus size to create a new corpus, or a pre-compiled corpus
get_feature_vectors <- function(tokens_list, corpus_size=nrow(word_list), corpus=NULL){
  if(is.null(corpus)){
    corpus <- corpus_freq(tokens_list, corpus_size=corpus_size, word_list)
  }
  
  #Our feature matrix starts out as an all 0 matrix with N by C dimensions
  feature_matrix <- matrix(0, length(tokens_list), nrow(corpus))
  #For every document in our tokenized list, calculate the tfidf feature vector, and put it into our feature matrix row-wise
  
  for(i in 1:length(tokens_list)){
    feature_vector <- tfidf(tokens_list[[i]], corpus)$tfidf
    if (is.null(feature_vector)) browser()
    feature_matrix[i, 1:nrow(corpus)] <- feature_vector
  }
  
  #The column names are the same as the alphabetical list of words in our corpus
  #Unnecessary step, but useful for examining the resulting feature matrix
  colnames(feature_matrix) <- corpus$Word
  return(data.frame(feature_matrix))
}


#add_targets takes our feature matrix, and the original data frame (with the documents in the same order) and adds the dependent variable for model training. In this case it's our pre-labeled sentiment.
add_targets <- function(feature_matrix, df){
  feature_matrix$sentiment <- df$sentiment
  return(feature_matrix)
}


#The ensemble function takes a list of prediction vectors, each with a length equal to the number of documents, and takes a majority vote.
ensemble <- function(predictions){
  votes <- matrix(0, length(predictions), length(predictions[[1]]))
  for(i in 1:length(predictions)){
    votes[i,] <- ifelse(predictions[[i]] == "P",1,0)
  }
  vote_decision <- colSums(votes)/nrow(votes)
  vote_decision <- ifelse(vote_decision >= .5,"P", "N")
  
  return(vote_decision)
}


#Calculates accuracy, true negative, true positive, and positive predictive value of a confusion matrix.
sensitivity <- function(confusion_matrix){
  acc <- (confusion_matrix[1]+confusion_matrix[4])/sum(confusion_matrix)
  tn <- (confusion_matrix[1]) / (confusion_matrix[3]+confusion_matrix[1])
  ppv <- confusion_matrix[4]/(confusion_matrix[4]+confusion_matrix[3])
  tp <- (confusion_matrix[4]) / (confusion_matrix[4]+confusion_matrix[2])
  return(list(accuracy=acc, specificity=tn, precision=ppv, sensitivity=tp))
}