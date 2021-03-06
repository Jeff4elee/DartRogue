library WORLD;

import 'TileObject/TileObject.dart';
import 'TileObject/TileType.dart';
import 'Room/RoomType.dart';
import 'Room/Room.dart';
import '../Entity/Player/Player.dart';
import '../Game/Game.dart';
import '../Entity/Monster/MonsterType.dart';
import '../Entity/Monster/Monster.dart';
import 'dart:math';
import '../Items/Enum.dart';
import '../Entity/Player/PlayerType.dart';
import '../Entity/Pathfinding/grid.dart';
import '../Entity/Pathfinding/astar.dart';
import '../Items/Item/ItemType.dart';
import '../Items/Weapon/WeaponType.dart';
import '../Items/Armor/ArmorType.dart';
import '../Items/Item/Item.dart';
import '../Items/Item/Chest.dart';
import '../Items/Armor/Armor.dart';
import '../Items/Weapon/Weapon.dart';
import '../ChooseRandom/ChooseRandom.dart';
import '../Entity/Monster/RangedMonster.dart';

class World
{
  Grid grid;
  int width;
  int height;
  List<Room> rooms = [];
  List<Monster> monsters = [];
  Player player;
  ChooseRandom roomTypes = new ChooseRandom();
  ChooseRandom roomSizes = new ChooseRandom();

  World(this.width, this.height)
  {
    this.grid = new Grid(this.width, this.height);
    clearGrid();

    roomTypes.add(RoomType.MONSTERROOM, 20);
    roomTypes.add(RoomType.NORMAL,  50);
    roomTypes.add(RoomType.SPIKEROOM, 25);
    roomTypes.add(RoomType.TREASUREROOM, 5);

    roomSizes.add("large", 20);
    roomSizes.add("small", 80);

    generateContent();
  }

  void generateContent()
  {
    generateRooms(getPosOrNeg((this.width*this.height)~/350, (this.width *this.height)~/900));
    loopDigCorridors();
    setRoom();
    display.refreshStats(player);
    loopTiles();
  }

  void timeStep()
  {
    timeStepMonsters();
    loopTiles();
    display.refreshStats(player);
  }

  void timeStepMonsters()
  {
    //
    var astar = new AStarFinder();
    for(int i = 0, length = monsters.length; i < length; i++)
    {
      var monster = monsters[i];
      if(monster.followingCountdown > 0)
      {
        monster.pathToPlayer = astar.findPath(monster.point, this.player.point, grid.clone());
      }
    }

    monsters.sort((a,b) => a.pathToPlayer.length.compareTo(b.pathToPlayer.length));
    for(int i = 0; i < monsters.length; i++)
    {
      monsters[i].timeStep(this);
    }
  }

  void loopTiles()
  {
    if(shadowsOn)
    {
      for(int i = 0; i < this.height; i++)
      {
        for(int j = 0; j < this.width; j++)
        {
          grid.nodes[i][j].isVisible = false;
        }
      }
    }

    for(int i = 0; i < this.height; i++)
    {
      for(int j = 0; j < this.width; j++)
      {
        lineOfSight(new Point(player.tileObject.point.x, player.tileObject.point.y), new Point(j, i));
      }
    }
  }

  void lineOfSight(Point point,Point point2)
  {
      int w = point2.x - point.x ;
      int h = point2.y - point.y ;
      int dx1 = 0, dy1 = 0, dx2 = 0, dy2 = 0 ;

      if (w<0) dx1 = -1 ; else if (w>0) dx1 = 1 ;
      if (h<0) dy1 = -1 ; else if (h>0) dy1 = 1 ;
      if (w<0) dx2 = -1 ; else if (w>0) dx2 = 1 ;
      int longest = w.abs();
      int shortest = h.abs();
      if (!(longest > shortest))
      {
          longest = h.abs() ;
          shortest = w.abs() ;
          if (h<0) dy2 = -1 ; else if (h>0) dy2 = 1 ;
          dx2 = 0 ;
      }

      int numerator = longest >> 1 ;
      for (int i=0;i<=longest;i++)
      {
        var tileObject = grid.nodes[point.y][point.x];
        tileObject.isVisible = true;

        if(tileObject.type == MonsterType.LIZARD)
        {
          RangedMonster monster = tileObject;
          monster.setProjectilePath(this);
          if(monster.followingCountdown < monster.COUNTMAX)
          {
            monster.followCountSetMax();
          }
        }
        else if(tileObject is Monster)
        {
          Monster monster = tileObject;
          if(monster.followingCountdown < monster.COUNTMAX)
          {
            monster.followCountSetMax();
          }
        }

        if (!grid.nodes[point.y][point.x].isOpaque) break;

        numerator += shortest ;
        if (!(numerator < longest))
        {
            numerator -= longest ;
            point = new Point(point.x + dx1, point.y + dy1);
        }
        else
        {
            point = new Point(point.x + dx2, point.y + dy2);
        }
      }
  }

  void clearGrid()
  {
    var row = [];

    for(int y = 0, height = this.height; y < height; y++)
    {
      row = [];
      for(int x = 0, width = this.width; x < width; x++)
      {
        if(!shadowsOn)
        {
          row.add(new TileObject(new Point( x, y), TileType.STONE));
        }
        else
        {
          row.add(new TileObject(new Point( x, y), TileType.WALL));
        }
      }
      grid.nodes.add(row);
    }
  }

  void generateRooms(int numOfRooms)
  {
    List<RoomType> defaultRooms = [RoomType.STARTROOM, RoomType.TREASUREROOM];

    for(int i = 0; i < numOfRooms; i++)
    {
      int roomWidth;
      int roomHeight;
      if(roomSizes.pick() == "small")
      {
        roomWidth = getPosOrNeg(10, 4);
        roomHeight = getPosOrNeg(10 , 4);
      }
      else
      {
        roomWidth = RNG.nextInt(10) + 14;
        roomHeight = RNG.nextInt(10) + 14;
      }

      int x = this.width - roomWidth - RNG.nextInt(width - roomWidth);
      int y = this.height - roomHeight  - RNG.nextInt(height - roomHeight);
      Room room;
      if(i < defaultRooms.length)
      {
        room = new Room(x, y, roomWidth, roomHeight, defaultRooms[i]);
      }
      else
      {
        room = new Room(x, y, roomWidth, roomHeight, roomTypes.pick());
      }
      bool intersects = false;
      for(int j = 0, length = rooms.length; j < length; j++)
      {
        if(room.intersects(rooms[j]))
        {
          intersects = true;
          break;
        }
      }
      if(!intersects)
      {
        this.rooms.add(room);
      }
      else
      {
        i--;
      }
    }
  }

  void setRoom()
  {
    for(int i = 0, length = rooms.length; i < length; i++) //number of rooms to iterate through
    {
      Room room = rooms[i];
      for(int j = 0, height = room.contents.length; j < height; j++) // height of the room
      {
        for(int k = 0, width = room.contents[0].length; k < width; k++)
        {
          Enum object = room.contents[j][k];
          setTileTypeAtPoint(new Point( room.minX + k, room.minY + j), object);
        }
      }
    }
  }

  void loopDigCorridors()
  {
    for(int i = 1, length = rooms.length; i < length; i++)
    {
      Room oldRoom = rooms[i - 1];
      Room newRoom = rooms[i];

      digCorridor(oldRoom.midX, newRoom.midX, oldRoom.midY, 1); //hor
      digCorridor(oldRoom.midY, newRoom.midY, newRoom.midX, 0 ); //ver
    }
  }

  void digCorridor(int pos1, int pos2, int constantPos, int dir)
  {
    for(int i = min(pos1, pos2), maxPos = max(pos1, pos2); i < maxPos + 1 + dir; i++)
    {
      if(dir == 1)
      {
        setTileTypeAtPoint(new Point(i, constantPos + 1), TileType.GROUND);
        setTileTypeAtPoint(new Point(i, constantPos), TileType.GROUND);
      }
      else
      {
        setTileTypeAtPoint(new Point(constantPos + 1, i), TileType.GROUND);
        setTileTypeAtPoint(new Point(constantPos, i), TileType.GROUND);
      }
    }
  }

  void setTileTypeAtPoint(Point coord, Enum type)
  {
    if(type is TileType)
    {
      grid.nodes[coord.y][coord.x] = new TileObject(coord, type);
    }
    else if(type is MonsterType)
    {
      if(type != MonsterType.LIZARD)
      {
        grid.nodes[coord.y][coord.x] = new Monster(coord, type);
      }
      else
      {
        grid.nodes[coord.y][coord.x] = new RangedMonster(coord, type);
      }
      monsters.add(grid.nodes[coord.y][coord.x]);
    }
    else if(type is PlayerType)
    {
      grid.nodes[coord.y][coord.x] = new Player(coord, type);
      player = getAtPoint(coord);
    }
    else if(type == ItemType.TREASURECHEST)
    {
      grid.nodes[coord.y][coord.x] = new Chest(coord);
    }
    else if(type is WeaponType)
    {
      grid.nodes[coord.y][coord.x] = new Weapon(coord, type);
    }
    else if(type is ArmorType)
    {
      grid.nodes[coord.y][coord.x] = new Armor(coord, type);
    }
    else if(type is ItemType)
    {
      grid.nodes[coord.y][coord.x] = new Item(coord, type);
    }
  }

  void setAtPoint(Point coord, dynamic thing)
  {
    this.grid.nodes[coord.y][coord.x] = thing;
  }

  TileObject getAtPoint(Point atPoint)
  {
    return grid.nodes[atPoint.y][atPoint.x];
  }
}