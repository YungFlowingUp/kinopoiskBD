DROP VIEW IF EXISTS film_view, film_genre_view, film_audience_view, film_actors_view;
DROP TABLE IF EXISTS genre, person, film, film_genre, film_person, film_viewer;
DROP TYPE IF EXISTS mpaa;
DROP DOMAIN IF EXISTS money_in_dollars;


--Создание пользовательских типов

CREATE TYPE mpaa AS ENUM ('G', 'PG', 'PG-13', 'R', 'NC-17');

CREATE DOMAIN money_in_dollars bigint
CHECK (VALUE >= 0);


--Создание таблиц

CREATE TABLE genre
(
	genre_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	genre varchar(30) UNIQUE NOT NULL,
	quantity_films int DEFAULT 0 NOT NULL
);

CREATE TABLE person
(
	person_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	fullname varchar(45) NOT NULL	
);

CREATE TABLE film
(
	film_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	name text NOT NULL,
	year smallint CHECK(year >= 1878 AND year <= date_part('year', CURRENT_DATE)) NOT NULL,
	rating numeric(2,1) CHECK(rating >= 0 AND rating <= 10) NOT NULL,
	country varchar(30) NOT NULL,
	slogan text,
	director_id int REFERENCES person(person_id) NOT NULL,
	writer_id int REFERENCES person(person_id),
	producer_id int REFERENCES person(person_id) NOT NULL,
	operator_id int REFERENCES person(person_id) NOT NULL,
	composer_id int REFERENCES person(person_id),
	art_id int REFERENCES person(person_id),
	effects_id int REFERENCES person(person_id),
	budget money_in_dollars NOT NULL,
	marketing money_in_dollars,
	gross_US money_in_dollars,
	gross_world money_in_dollars NOT NULL,
	premiere_russia date CHECK(date_part('year', premiere_russia) >= year 
		AND premiere_russia <= CURRENT_DATE),
	premiere_world date CHECK(date_part('year', premiere_world) >= year 
		AND premiere_world <= CURRENT_DATE),
	dvd_release date CHECK(date_part('year', dvd_release) >= year 
		AND dvd_release <= CURRENT_DATE),
	blu_ray_release date CHECK(date_part('year', blu_ray_release) >= year 
		AND blu_ray_release <= CURRENT_DATE),
	min_age smallint CHECK(min_age >= 0),
	rating_MPAA mpaa,
	duration_in_minutes int CHECK(duration_in_minutes >= 0) NOT NULL
);

CREATE TABLE film_genre
(
	film_id int REFERENCES film(film_id) ON DELETE CASCADE,
	genre_id int REFERENCES genre(genre_id) ON DELETE CASCADE,
	
	CONSTRAINT film_genre_pk PRIMARY KEY (film_id, genre_id)
);

CREATE TABLE film_person
(
	film_id int REFERENCES film(film_id) ON DELETE CASCADE,
	person_id int REFERENCES person(person_id) ON DELETE CASCADE,
	role varchar(10) CHECK(role IN('Главная', 'Дубляж')) NOT NULL,
	
	CONSTRAINT film_person_pk PRIMARY KEY (film_id, person_id)
);

CREATE TABLE film_viewer
(	
	film_id int REFERENCES film(film_id) ON DELETE CASCADE,
	country varchar(30) NOT NULL,
	quantity real NOT NULL,
	
	CONSTRAINT viewer_film_pk PRIMARY KEY (film_id, country)
);


--Создание триггера, на проверку добавления в таблицу person человека с таким же именем

CREATE OR REPLACE FUNCTION check_person_name_fnc()
  RETURNS trigger AS
$$
DECLARE 
	old_id integer;
	mes_ln1 text := E'\n' || 'Человек с такиим именем уже существует в базе данных:';
	mes_ln2 text := E'\n' || 'Данный человек уже принмал участие в фильме -';
	mes_ln3 text := E'\n' || 'Если вы хотели добавить этого же человека, то введите команду:';
	mes_ln4 text := E'\n' || 'DELETE FROM person WHERE person_id =';
	mes_ln5 text := E'\n' || 'В ином случае проигнорируйте это сообщение.';
	film text;
BEGIN	
	SELECT person_id INTO old_id
	FROM person
	WHERE fullname = NEW.fullname;
	
	IF old_id IS NOT NULL THEN
		SELECT name INTO film
		FROM film
		JOIN film_person ON film.film_id = film_person.film_id
		WHERE director_id = old_id OR 
			  producer_id = old_id OR
			  operator_id = old_id OR
			  composer_id = old_id OR
			  art_id = old_id OR
			  effects_id = old_id OR
			  person_id = old_id;
		Raise Notice '% % % % % % %', mes_ln1, mes_ln2, film, mes_ln3, mes_ln4, NEW.person_id, mes_ln5;
	END IF;
	
	RETURN NEW;
	END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER check_person_name
	BEFORE INSERT ON person
	FOR EACH ROW
	EXECUTE PROCEDURE check_person_name_fnc();

--Создание триггера, на изменение таблицы film_genre, с автоматическим изменением данных в таблице genre 

--insert trigger
CREATE OR REPLACE FUNCTION insert_genre_qantity_fnc()
  RETURNS trigger AS
$$
DECLARE 
	counter integer;	
BEGIN
	SELECT COUNT(*) INTO counter
	FROM film_genre
	WHERE genre_id = NEW.genre_id;		
	UPDATE genre SET quantity_films = counter WHERE genre_id = NEW.genre_id;
	
	RETURN NEW;
	END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER insert_genre_qantity
	AFTER INSERT ON film_genre
	FOR EACH ROW
	EXECUTE PROCEDURE insert_genre_qantity_fnc();


--update trigger
CREATE OR REPLACE FUNCTION update_genre_qantity_fnc()
  RETURNS trigger AS
$$
DECLARE 
	counter integer;	
BEGIN
	SELECT COUNT(*) INTO counter
	FROM film_genre
	WHERE genre_id = NEW.genre_id;		
	UPDATE genre SET quantity_films = counter WHERE genre_id = NEW.genre_id;
	
	SELECT COUNT(*) INTO counter
	FROM film_genre
	WHERE genre_id = OLD.genre_id;
	UPDATE genre SET quantity_films = counter WHERE genre_id = OLD.genre_id;
	
	RETURN NEW;
	END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER update_genre_qantity
	AFTER UPDATE ON film_genre
	FOR EACH ROW
	EXECUTE PROCEDURE update_genre_qantity_fnc();


--delete trigger
CREATE OR REPLACE FUNCTION delete_genre_qantity_fnc()
  RETURNS trigger AS
$$
DECLARE 
	counter integer;	
BEGIN
	SELECT COUNT(*) INTO counter
	FROM film_genre
	WHERE genre_id = OLD.genre_id;
	UPDATE genre SET quantity_films = counter WHERE genre_id = OLD.genre_id;
	
	RETURN NEW;
	END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER delete_genre_qantity
	AFTER DELETE ON film_genre
	FOR EACH ROW
	EXECUTE PROCEDURE delete_genre_qantity_fnc();
	
	
--Создание предствалений

--Выборка фильмов(без зрителей, жанров и актеров) 
CREATE VIEW film_view AS
	SELECT name AS Название, year AS Год_выпуска, country AS Страна, 
	   rating AS Рейтинг, slogan AS Слоган,
	   (SELECT fullname FROM person WHERE director_id = person_id) AS Режиссер,
	   (SELECT fullname FROM person WHERE writer_id = person_id) AS Сценарист,
	   (SELECT fullname FROM person WHERE producer_id = person_id) AS Продюсер,
	   (SELECT fullname FROM person WHERE operator_id = person_id) AS Оператор,
	   (SELECT fullname FROM person WHERE composer_id = person_id) AS Композитор,
	   (SELECT fullname FROM person WHERE art_id = person_id) AS Художник,
	   (SELECT fullname FROM person WHERE effects_id = person_id) AS Монтаж,
	   budget AS Бюджет_$, marketing AS Маркетинг_$, gross_US AS Сборы_в_США_$, 
	   gross_world AS Сборы_в_мире_$, premiere_russia AS Премьера_в_Росcии, 
	   premiere_world AS Премьера_в_мире, dvd_release AS Релиз_на_DVD, 
	   blu_ray_release AS Релиз_на_Bluray, min_age AS Возраст, 
	   rating_MPAA AS Рейтинг_MPAA, duration_in_minutes AS Длительность_в_минутах
	FROM film;
	
--Выборка фильмов и их жанров
CREATE VIEW film_genre_view AS
	SELECT name AS Фильм, genre AS Жанр
	FROM film_genre
	JOIN film USING(film_id)
	JOIN genre USING(genre_id)
	ORDER BY Фильм;

--Выборка фильмов и их зрителей
CREATE VIEW film_audience_view AS
	SELECT name AS Фильм, film_viewer.country AS Страна, quantity AS Количество_в_млн
	FROM film_viewer
	JOIN film USING(film_id)
	ORDER BY Фильм;
	
--Выборка фильмов и актеров, сыгравших в них	
CREATE VIEW film_actors_view AS
	SELECT name AS Фильм, fullname AS Актёр, role AS Роль
	FROM film_person
	JOIN film USING(film_id)
	JOIN person USING(person_id)
	ORDER BY Фильм DESC;	
	
	
--Заполнение таблиц данными

INSERT INTO genre(genre) VALUES 
	('драма'),
	('фэнтези'),
	('криминал'),
	('комедия'),
	('история'),	
	('приключения'),
	('боевик'),
	('фантастика'),
	('мелодрама');

INSERT INTO person(fullname) VALUES 
	('Том Хэнкс'),
	('Дэвид Морс'),
	('Бонни Хант'),
	('Майкл Кларк Дункан'),
	('Джеймс Кромуэлл'),
	('Всеволод Кузнецов'),
	('Владимир Антоник'),
	('Любовь Германова'),
	('Валентин Голубенко'),
	('Александр Белявский'),
	('Фрэнк Дарабонт'),
	('Дэвид Тэттерсолл'),
	('Томас Ньюман'),
	('Теренс Марш'),
	('Ричард Фрэнсис-Брюс'),
	('Мариана Тревино'),
	('Рэйчел Келлер'),
	('Мануэль Рульфо'),
	('Станислав Концевич'),
	('Лилия Касаткина'),
	('Марк Форстер'),
	('Ханнес Холм'),
	('Неда Бакман'),
	('Маттиас Кёнигсвизер'),	
	('Барбара Линг'),
	('Мэтт Шесс'),
	('Элайджа Вуд'),
	('Иэн Маккеллен'),
	('Шон Эстин'),
	('Вигго Мортенсен'),
	('Алексей Елистратов'),
	('Рогволд Суховерко'),
	('Геннадий Карпов'),
	('Алексей Рязанцев'),	
	('Фрэн Уолш'),
	('Питер Джексон'),
	('Эндрю Лесни'),
	('Говард Шор'),
	('Грант Мейджор'),
	('Джон Гилберт'),
	('Сэм Уортингтон'),
	('Зои Салдана'),
	('Александр Ноткин'),
	('Мария Цветкова-Овсянникова'),
	('Джеймс Кэмерон'),
	('Мауро Фиоре'),
	('Джеймс Хорнер'),
	('Рик Картер');
	
INSERT INTO film(name, year, rating, country, slogan, director_id, 
				 writer_id, producer_id, operator_id, composer_id,
				 art_id, effects_id, budget, marketing, gross_US, 
				 gross_world, premiere_russia, premiere_world, 
				 dvd_release, blu_ray_release, min_age, rating_MPAA, 
				 duration_in_minutes) VALUES 
	('Зеленая миля', 1999, 9.1, 'США', 'Пол Эджкомб не верил в чудеса. 
	 Пока не столкнулся с одним из них', 11, 11, 11, 12, 13, 14, 15, 60000000, 
	 30000000, 136801374, 286801374, '2000-04-18', '1999-12-6', '2001-02-13', NULL, 16, 'R', 189),
	('Мой ужасный сосед', 2022, 7.5, 'США, Швеция', 'На самом деле он улыбается... 
	 Где-то внутри', 21, 22, 23, 24, 13, 25, 26, 50000000, NULL, 63611261, 107011261, 
	 NULL, '2022-12-25', NULL, NULL, NULL, 'PG-13', 126),
	('Властелин колец: Братство Кольца', 2001, 8.6, 'Новая Зеландия, США', NULL, 
	 36, 35, 36, 37, 38, 39, 40, 93000000, 50000000, 316115420, 898204420, '2002-02-7',
	 '2001-12-10', '2002-12-3', '2010-4-6', 12, 'PG-13', 178),
	('Аватар', 2009, 8.0, 'США', 'Это новый мир', 45, 45, 45, 46, 47, 48, 45, 237000000, NULL,
	 785221649, 2923905528, '2009-12-17', '2009-12-10', '2010-04-22', '2010-4-29', 12, 'PG-13', 162);
	
INSERT INTO film_genre(film_id, genre_id) VALUES 
	(1, 1),
	(1, 2),
	(1, 3),
	(2, 1),
	(2, 4),
	(3, 1),
	(3, 2),
	(3, 6),
	(3, 7),
	(4, 1),
	(4, 6),
	(4, 7),
	(4, 8);
	
INSERT INTO film_person(film_id, person_id, role) VALUES
	(1, 1, 'Главная'),
	(1, 2, 'Главная'),
	(1, 3, 'Главная'),
	(1, 4, 'Главная'),
	(1, 5, 'Главная'),
	(1, 6, 'Дубляж'),
	(1, 7, 'Дубляж'),
	(1, 8, 'Дубляж'),
	(1, 9, 'Дубляж'),
	(1, 10, 'Дубляж'),
	(2, 1, 'Главная'),
	(2, 16, 'Главная'),
	(2, 17, 'Главная'),
	(2, 18, 'Главная'),
	(2, 19, 'Дубляж'),
	(2, 20, 'Дубляж'),
	(3, 27, 'Главная'),
	(3, 28, 'Главная'),
	(3, 29, 'Главная'),
	(3, 30, 'Главная'),
	(3, 31, 'Дубляж'),
	(3, 32, 'Дубляж'),
	(3, 33, 'Дубляж'),
	(3, 34, 'Дубляж'),
	(4, 41, 'Главная'),
	(4, 42, 'Главная'),
	(4, 43, 'Дубляж'),
	(4, 44, 'Дубляж');
	
INSERT INTO film_viewer(film_id, country, quantity) VALUES 
	(1, 'США', 26),
	(1, 'Германия', 2.1),
	(1, 'Италия', 1.7),
	(3, 'США', 54.6),
	(3, 'Великобритания', 14.7),
	(3, 'Германия', 11),
	(4, 'США', 97.3),
	(4, 'Китай', 27.6),
	(4, 'Великобритания', 16.5);	
	

