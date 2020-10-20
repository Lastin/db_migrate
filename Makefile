.PHONY: reset

reset:
	docker-compose kill
	docker-compose rm -f mysql
	docker-compose up -d

run:
	docker-compose exec mysql bash -c "/ecs/script.sh /ecs/scripts localhost root ecs"