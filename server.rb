require 'sinatra'
require 'pg'
require 'pry'

#####################################
#             METHODS
#####################################

def db_connection
  begin
    connection = PG.connect(dbname: 'movies')

    yield(connection)

  ensure
    connection.close
  end
end

def sort_by_name(actors)
  actors.sort_by { |actor| actor['name'] }
end

def get_all_actors
  query = 'SELECT * FROM actors'

  results = db_connection do |conn|
    conn.exec(query)
  end

  results.to_a
end

def get_all_movies(offset = 0)
  query = %Q{
    SELECT movies.title, movies.year, movies.id, movies.rating, genres.name AS genre, studios.name AS studio
    FROM movies
    JOIN genres ON genres.id = movies.genre_id
    JOIN studios ON studios.id = movies.studio_id
    LIMIT 20 OFFSET $1
  }

  results = db_connection do |conn|
    conn.exec_params(query, [offset])
  end

  movies = []

  results.each do |movie|
    movie = {
      id: movie['id'].to_i,
      title: movie['title'],
      year: movie['year'].to_i,
      rating: movie['rating'].to_i,
      genre: movie['genre'],
      studio: movie['studio']
    }
    movies << movie
  end

  movies
end

def get_actor_info(actor_id)
  query = %Q{
    SELECT actors.name AS actor, movies.title AS movie_title, movies.id AS movie_id, cast_members.character AS role
    FROM actors
    JOIN cast_members ON actors.id = cast_members.actor_id
    JOIN movies ON movies.id = cast_members.movie_id
    WHERE actors.id = $1;
  }

  results = db_connection do |conn|
    conn.exec_params(query, [actor_id])
  end

  results.to_a
end

def get_movie_info(movie_id)
  query = %Q{
    SELECT movies.title, movies.year, movies.id, movies.rating, genres.name AS genre, studios.name AS studio,
    actors.id AS actor_id, actors.name AS actor, cast_members.character AS role
    FROM movies
    JOIN genres ON genres.id = movies.genre_id
    JOIN studios ON studios.id = movies.studio_id
    JOIN cast_members ON cast_members.movie_id = movies.id
    JOIN actors ON actors.id = cast_members.actor_id
    WHERE movies.id = $1;
  }

  results = db_connection do |conn|
    conn.exec_params(query, [movie_id])
  end

  results.to_a
end

def movies_appeared_in(actor_results)
  movies = []

  actor_results.each do |result|
    movies << {
      title: result['movie_title'],
      id: result['movie_id'],
      role: result['role'],
      rating: result['rating'].to_i
    }
  end

  movies
end

def cast_for_movie(results)
  cast = []

  results.each do |result|
    cast << {
      actor_id: result['actor_id'],
      actor: result['actor'],
      role: result['role']
    }
  end

  cast
end

def order_by(movies, attribute)
  movies.sort_by { |movie| movie[attribute.to_sym] }
end

#####################################
#             ROUTES
#####################################

get '/actors' do
  results = get_all_actors

  @actors = sort_by_name(results)

  erb :'actors/index'
end

get '/actors/:id' do
  actor_id = params[:id]

  results = get_actor_info(actor_id)

  if !results.empty?
    @actor_name = results[0]['actor']
  else
    @actor_name = ''
  end

  @movies = movies_appeared_in(results)

  erb :'actors/show'
end

get '/movies' do
  # results = get_all_movies
  if params[:page]
    offset = (params[:page].to_i - 1) * 20 - 1
    results = get_all_movies(offset)
  else
    results = get_all_movies
  end

  if params[:order]
    @movies = order_by(results, params[:order])
  else
    @movies = order_by(results, :title)
  end

  erb :'movies/index'
end

get '/movies/:id' do
  movie_id = params[:id]

  results = get_movie_info(movie_id)

  if !results.empty?
    @movie = {
      id: results[0]['id'],
      title: results[0]['title'],
      year: results[0]['year'],
      genre: results[0]['genre'],
      studio: results[0]['studio']
    }
  else
    @movie = {}
  end

  @cast = cast_for_movie(results)

  erb :'movies/show'
end
